#if !SDK_V10
// V9-only compatibility implementation, including its 70-thread/100-frame/128-byte-name
// limits. Remove this implementation and its machine-context seam when V9 is retired.
// swiftlint:disable missing_docs
internal import _SentryPrivate
import Foundation

@_spi(Private) @objc public class SentryDefaultThreadInspector: NSObject {
    private let stacktraceBuilder: SentryStacktraceBuilder
    private let machineContextWrapper: SentryCrashMachineContextWrapper
    private let threadCaptureLock = SentryMutex(())

    @objc public init(
        stacktraceBuilder stacktraceBuilderObject: AnyObject,
        andMachineContextWrapper machineContextWrapperObject: AnyObject
    ) {
        stacktraceBuilder = unsafeDowncast(
            stacktraceBuilderObject,
            to: SentryStacktraceBuilder.self
        )
        machineContextWrapper = unsafeDowncast(
            machineContextWrapperObject,
            to: SentryCrashMachineContextWrapper.self
        )
        super.init()
    }

    @objc public convenience init(options: NSObject?) {
        let stacktraceBuilder = sentryDefaultThreadInspectorCreateStacktraceBuilder(
            (options as? Options)?.inAppIncludes ?? []
        )
        self.init(
            stacktraceBuilder: stacktraceBuilder,
            andMachineContextWrapper: SentryCrashDefaultMachineContextWrapper()
        )
    }

    @objc public func stacktraceForCurrentThreadAsyncUnsafe() -> SentryStacktrace? {
        stacktraceBuilder.buildStacktraceForCurrentThreadAsyncUnsafe()
    }

    @objc public func getCurrentThreads() -> [SentryThread] {
        var threads: [SentryThread] = []
        var context = SentryCrashMachineContext()
        let currentThread = sentrycrashthread_self()

        machineContextWrapper.fillContext(forCurrentThread: &context)
        let threadCount = machineContextWrapper.getThreadCount(&context)

        for index in 0..<threadCount {
            let thread = machineContextWrapper.getThread(&context, with: index)
            let sentryThread = SentryThread(threadId: NSNumber(value: index))

            sentryThread.isMain = NSNumber(
                value: machineContextWrapper.isMainThread(thread)
            )
            sentryThread.name = getThreadName(thread)

            sentryThread.crashed = NSNumber(value: false)
            let isCurrent = thread == currentThread
            sentryThread.current = NSNumber(value: isCurrent)

            if isCurrent {
                sentryThread.stacktrace = stacktraceBuilder.buildStacktraceForCurrentThread()
            }

            if machineContextWrapper.isMainThread(thread) {
                threads.insert(sentryThread, at: 0)
            } else {
                threads.append(sentryThread)
            }
        }

        return threads
    }

    @objc public func getCurrentThreadsWithStackTrace() -> [SentryThread] {
        threadCaptureLock.withLock { _ in
            guard let threadInfoBuffer = sentryDefaultThreadInspectorCaptureThreads() else {
                return []
            }
            defer {
                sentryDefaultThreadInspectorFreeThreadInfoBuffer(threadInfoBuffer)
            }

            let threadCount = sentryDefaultThreadInspectorGetThreadCount(threadInfoBuffer)
            if threadCount == 0 {
                return []
            }

            let currentThread = sentryDefaultThreadInspectorGetCurrentThread(threadInfoBuffer)
            var threads: [SentryThread] = []

            for index in 0..<threadCount {
                let thread = sentryDefaultThreadInspectorGetThread(threadInfoBuffer, index)
                let sentryThread = SentryThread(threadId: NSNumber(value: index))

                sentryThread.isMain = NSNumber(value: index == 0)
                sentryThread.name = getThreadName(thread)

                sentryThread.crashed = NSNumber(value: false)
                let isCurrent = thread == currentThread
                sentryThread.current = NSNumber(value: isCurrent)

                if isCurrent {
                    sentryThread.stacktrace = stacktraceBuilder.buildStacktraceForCurrentThread()
                } else {
                    sentryThread.stacktrace = stacktraceBuilder.buildStackTrace(
                        fromStackEntries: sentryDefaultThreadInspectorGetStackEntries(
                            threadInfoBuffer,
                            index
                        ),
                        amount: sentryDefaultThreadInspectorGetStackLength(
                            threadInfoBuffer,
                            index
                        )
                    )
                }

                if machineContextWrapper.isMainThread(thread) {
                    threads.insert(sentryThread, at: 0)
                } else {
                    threads.append(sentryThread)
                }
            }

            return threads
        }
    }

    @objc public func getThreadName(_ thread: UInt) -> String? {
        let bufferLength: Int32 = 128
        var buffer = [CChar](repeating: 0, count: Int(bufferLength))

        return buffer.withUnsafeMutableBufferPointer { bufferPointer in
            guard let baseAddress = bufferPointer.baseAddress else {
                return nil
            }
            let didGetThreadNameSucceed = machineContextWrapper.getThreadName(
                thread,
                andBuffer: baseAddress,
                andBufLength: bufferLength
            )
            guard didGetThreadNameSucceed,
                  let threadName = String(validatingUTF8: baseAddress),
                  !threadName.isEmpty
            else {
                return nil
            }
            return threadName
        }
    }
}
// swiftlint:enable missing_docs
#endif
