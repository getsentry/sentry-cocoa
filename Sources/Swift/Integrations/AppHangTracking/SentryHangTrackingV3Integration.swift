// Only gated for these platforms so we can use Combine
#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
@_implementationOnly import _SentryPrivate
import Combine

protocol SentryHangTrackingV3IntegrationProtocol {}

typealias SentryHangTrackingV3IntegrationDependencies = AppHangTrackerProvider & ClientProvider & ThreadInspectorProvider & DebugImageProvider & HubProvider

final class SentryHangTrackingV3Integration<Dependencies: SentryHangTrackingV3IntegrationDependencies>: NSObject, SwiftIntegration, SentryHangTrackingV3IntegrationProtocol {

    private let appHangTracker: SentryAppHangTracker
    private let observer: SentryAppHangTrackerObserverToken

    init?(with options: Options, dependencies: Dependencies) {
        guard options.experimental.appHangs.enableV3 else {
            return nil
        }

        self.appHangTracker = dependencies.appHangTracker
        observer = appHangTracker.addObserver(threshold: options.experimental.appHangs.appHangThreshold) { hang in
            guard hang.state == .ended else { return }
            guard let client = dependencies.client else {
                SentrySDKLog.debug("SentryHangTrackingV3Integration: No client available, dropping hang event")
                return
            }

            let thread = SentryThread(threadId: NSNumber(value: 0))
            thread.name = "main"
            thread.crashed = NSNumber(value: false)
            thread.current = NSNumber(value: true)
            thread.isMain = NSNumber(value: true)

            let mechanism = Mechanism(type: "mx_hang_diagnostic")
            mechanism.handled = NSNumber(value: true)
            mechanism.synthetic = NSNumber(value: true)

            let exception = Exception(
                value: "App hang detected: \(String(format: "%.1f", hang.duration)) sec",
                type: "MXHangDiagnostic"
            )
            exception.mechanism = mechanism
            exception.threadId = NSNumber(value: 0)

            let event = Event(level: .warning)
            event.threads = [thread]
            event.exceptions = [exception]

            if let profilerId = hang.profilerId {
                Self.attachProfile(
                    to: event,
                    profilerId: profilerId,
                    profilingData: hang.profilingData,
                    hub: dependencies.hub
                )
            }

            client.capture(event: event)
        }

        super.init()
    }

    private static func attachProfile(
        to event: Event,
        profilerId: SentryId,
        profilingData: SentryAppHang.ProfilingData?,
        hub: Hub
    ) {
        // Set profile context on event so backend links them
        var contexts = event.context ?? [:]
        contexts["profile"] = ["profiler_id": profilerId.sentryIdString]
        event.context = contexts

        // If we have custom profiling data (not from continuous profiler),
        // send it as a profile_chunk envelope
        guard let profilingData else { return }

        let profileDict = profilingData.toDictionary() as NSDictionary

        #if SENTRY_TARGET_PROFILING_SUPPORTED
        #if SENTRY_HAS_UIKIT
        let envelope = sentry_continuousProfileChunkEnvelope(
            profilerId,
            profileDict,
            [:], // no metric profiler data for hang profiles
            nil  // no GPU data for hang profiles
        )
        #else
        let envelope = sentry_continuousProfileChunkEnvelope(
            profilerId,
            profileDict,
            [:]  // no metric profiler data for hang profiles
        )
        #endif

        guard let envelope else {
            SentrySDKLog.debug("SentryHangTrackingV3Integration: Failed to create profile chunk envelope")
            return
        }

        hub.captureEnvelope(envelope)
        #endif
    }

    func uninstall() {}

    static var name: String {
        "SentryHangTrackingV3Integration"
    }
}

extension SentryAppHang.ProfilingData {
    func toDictionary() -> [String: Any] {
        let serializedFrames: [[String: Any]] = frames.map { frame in
            var dict: [String: Any] = [:]
            if let addr = frame.instructionAddress { dict["instruction_addr"] = addr }
            if let function = frame.function { dict["function"] = function }
            if let module = frame.module { dict["module"] = module }
            return dict
        }

        let serializedStacks: [[NSNumber]] = stacks.map { stack in
            stack.map { NSNumber(value: $0) }
        }

        let serializedSamples: [[String: Any]] = samples.map { sample in
            [
                "timestamp": NSNumber(value: Double(sample.absoluteTimestamp) / 1_000_000_000.0),
                "thread_id": "\(sample.threadId)",
                "stack_id": NSNumber(value: sample.stackIndex)
            ]
        }

        let serializedThreadMetadata: [String: [String: Any]] = threadMetadata.mapValues { meta in
            ["name": meta.name, "priority": NSNumber(value: meta.priority)]
        }

        return [
            "profile": [
                "frames": serializedFrames,
                "stacks": serializedStacks,
                "samples": serializedSamples,
                "thread_metadata": serializedThreadMetadata
            ]
        ]
    }
}
#endif
