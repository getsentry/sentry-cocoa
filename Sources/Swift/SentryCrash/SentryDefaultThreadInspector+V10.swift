#if SDK_V10
// swiftlint:disable missing_docs
internal import _SentryPrivate
import Foundation

struct SentryCapturedThread {
    let id: UInt
    let index: UInt
    let isMain: Bool
    let isCurrent: Bool
    let name: String?
    let addresses: [UInt]?
    var isTruncated = false
}

#if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
protocol SentryThreadSnapshotProviding {
    func capture(stacks: Bool) -> [SentryCapturedThread]
    func name(for thread: UInt) -> String?
}
#else
typealias SentryThreadSnapshotProviding = SentrySystemThreadSnapshotProvider
#endif

final class SentrySystemThreadSnapshotProvider {
    private let requiresCrashHandler: Bool

    init(requiresCrashHandler: Bool) {
        self.requiresCrashHandler = requiresCrashHandler
    }

    func capture(stacks: Bool) -> [SentryCapturedThread] {
        var buffer = SentryThreadSnapshotBuffer()
        guard sentryThreadSnapshotSystemCapture(stacks, requiresCrashHandler, &buffer) else {
            SentrySDKLog.debug("Thread snapshot capture unavailable.")
            return []
        }
        defer { sentryThreadSnapshotSystemDestroy(&buffer) }

        // The C entry point has resumed every owned suspension and released enumeration rights.
        // Only now may Swift allocate, decode names, and copy instruction addresses.
        return UnsafeBufferPointer(start: buffer.threads, count: buffer.count).map { snapshot in
            var snapshot = snapshot
            let name = withUnsafePointer(to: &snapshot.name) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: Int(SENTRY_THREAD_SNAPSHOT_NAME_LENGTH)) {
                    Self.decodeName($0)
                }
            }
            let hasStack = snapshot.status == SentryThreadCaptureSucceeded
                || snapshot.status == SentryThreadCaptureUnavailable
            let frameCount = snapshot.frameCount
            let addresses: [UInt]? = hasStack ? withUnsafePointer(to: &snapshot.addresses) { pointer in
                pointer.withMemoryRebound(to: UInt.self, capacity: Int(SENTRY_THREAD_SNAPSHOT_MAX_FRAMES)) {
                    Array(UnsafeBufferPointer(start: $0, count: frameCount))
                }
            } : nil
            return SentryCapturedThread(
                id: snapshot.thread, index: UInt(snapshot.index), isMain: snapshot.isMain,
                isCurrent: snapshot.isCurrent, name: name, addresses: addresses,
                isTruncated: snapshot.isTruncated
            )
        }
    }

    func name(for thread: UInt) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(SENTRY_THREAD_SNAPSHOT_NAME_LENGTH))
        return buffer.withUnsafeMutableBufferPointer { pointer in
            guard let address = pointer.baseAddress,
                  sentryThreadSnapshotCopyName(thread, address, pointer.count) else {
                return nil
            }
            return Self.decodeName(address)
        }
    }

    private static func decodeName(_ buffer: UnsafePointer<CChar>) -> String? {
        guard let name = String(validatingUTF8: buffer), !name.isEmpty else { return nil }
        return name
    }
}

#if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
extension SentrySystemThreadSnapshotProvider: SentryThreadSnapshotProviding { }
#endif

@_spi(Private) @objc public class SentryDefaultThreadInspector: NSObject {
    private let stacktraceBuilder: SentryStacktraceBuilder
    private let snapshotProvider: SentryThreadSnapshotProviding
    private let threadCaptureLock = SentryMutex(())

    init(stacktraceBuilder: SentryStacktraceBuilder, snapshotProvider: SentryThreadSnapshotProviding) {
        self.stacktraceBuilder = stacktraceBuilder
        self.snapshotProvider = snapshotProvider
        super.init()
    }

    @objc public convenience init(options: NSObject?) {
        let options = options as? Options
        self.init(
            stacktraceBuilder: sentryDefaultThreadInspectorCreateStacktraceBuilder(options?.inAppIncludes ?? []),
            // The dependency-container facade can be created before SDK options exist. Do not
            // permanently gate that instance on a handler the eventual SDK may disable. An
            // installation actually in progress is still blocked by the post-enumeration C policy.
            snapshotProvider: SentrySystemThreadSnapshotProvider(requiresCrashHandler: options?.enableCrashHandler ?? false)
        )
    }

    @objc public func stacktraceForCurrentThreadAsyncUnsafe() -> SentryStacktrace? {
        stacktraceBuilder.buildStacktraceForCurrentThreadAsyncUnsafe()
    }

    @objc public func getCurrentThreads() -> [SentryThread] {
        threads(stacks: false)
    }

    @objc public func getCurrentThreadsWithStackTrace() -> [SentryThread] {
        threads(stacks: true)
    }

    private func threads(stacks: Bool) -> [SentryThread] {
        threadCaptureLock.withLock { _ in
            var mainThreads: [SentryThread] = []
            var otherThreads: [SentryThread] = []
            for snapshot in snapshotProvider.capture(stacks: stacks) {
                // Preserve the existing event ID (enumeration ordinal), not the Mach identity.
                let thread = SentryThread(threadId: NSNumber(value: snapshot.index))
                thread.isMain = NSNumber(value: snapshot.isMain)
                thread.current = NSNumber(value: snapshot.isCurrent)
                thread.crashed = NSNumber(value: false)
                thread.name = snapshot.name
                if snapshot.isCurrent {
                    thread.stacktrace = stacktraceBuilder.buildStacktraceForCurrentThread()
                } else if stacks, let addresses = snapshot.addresses {
                    thread.stacktrace = stacktraceBuilder.buildStackTrace(fromAddresses: addresses.map { NSNumber(value: $0) })
                }
                // Truncation remains available at the neutral boundary. SentryStacktrace has no
                // corresponding event field; do not conflate it with the crashed-thread flag.
                if snapshot.isMain {
                    mainThreads.append(thread)
                } else {
                    otherThreads.append(thread)
                }
            }
            return mainThreads + otherThreads
        }
    }

    @objc public func getThreadName(_ thread: UInt) -> String? {
        snapshotProvider.name(for: thread)
    }
}
// swiftlint:enable missing_docs
#endif
