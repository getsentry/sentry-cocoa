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
            SentrySDKLog.debug("HangTrackingV3: Not enabled, skipping installation")
            return nil
        }

        SentrySDKLog.debug("HangTrackingV3: Installing with threshold=\(options.experimental.appHangs.appHangThreshold)s")
        self.appHangTracker = dependencies.appHangTracker
        observer = appHangTracker.addObserver(threshold: options.experimental.appHangs.appHangThreshold) { hang in
            SentrySDKLog.debug("HangTrackingV3: Observer callback — state=\(hang.state == .started ? "started" : "ended"), duration=\(hang.duration)s, profilerId=\(hang.profilerId?.sentryIdString ?? "nil")")
            guard hang.state == .ended else { return }
            guard let client = dependencies.client else {
                SentrySDKLog.debug("HangTrackingV3: No client available, dropping hang event")
                return
            }

            let thread = SentryThread(threadId: NSNumber(value: 0))
            thread.name = "main"
            thread.crashed = NSNumber(value: false)
            thread.current = NSNumber(value: true)
            thread.isMain = NSNumber(value: true)

            let mechanism = Mechanism(type: "AppHang")
            mechanism.handled = NSNumber(value: true)
            mechanism.synthetic = NSNumber(value: true)

            let exception = Exception(
                value: "App hang detected: \(String(format: "%.1f", hang.duration)) sec",
                type: "App Hanging"
            )
            exception.mechanism = mechanism
            exception.threadId = NSNumber(value: 0)

            let event = Event(level: .warning)
            event.threads = [thread]
            event.exceptions = [exception]

            if let profilerId = hang.profilerId {
                SentrySDKLog.debug("HangTrackingV3: Attaching profile (profilerId=\(profilerId.sentryIdString), hasProfilingData=\(hang.profilingData != nil))")
                Self.attachProfile(
                    to: event,
                    profilerId: profilerId,
                    profilingData: hang.profilingData,
                    hub: dependencies.hub
                )
            } else {
                SentrySDKLog.debug("HangTrackingV3: No profilerId, sending event without profile")
            }

            SentrySDKLog.debug("HangTrackingV3: Capturing hang event (eventId=\(event.eventId.sentryIdString))")
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
        SentrySDKLog.debug("HangTrackingV3: Set profile context on event (profiler_id=\(profilerId.sentryIdString))")

        // If we have custom profiling data (not from continuous profiler),
        // send it as a profile_chunk envelope
        guard let profilingData else {
            SentrySDKLog.debug("HangTrackingV3: No custom profiling data (continuous profiler path), skipping chunk envelope")
            return
        }

        SentrySDKLog.debug("HangTrackingV3: Serializing profiling data (frames=\(profilingData.frames.count), stacks=\(profilingData.stacks.count), samples=\(profilingData.samples.count))")

        guard let envelope = buildProfileChunkEnvelope(profilerId: profilerId, profilingData: profilingData, hub: hub) else {
            SentrySDKLog.debug("HangTrackingV3: Failed to build profile chunk envelope")
            return
        }

        SentrySDKLog.debug("HangTrackingV3: Sending profile_chunk envelope via hub.captureEnvelope")
        hub.captureEnvelope(envelope)
    }

    func uninstall() {}

    static var name: String {
        "SentryHangTrackingV3Integration"
    }
}

private func buildProfileChunkEnvelope(
    profilerId: SentryId,
    profilingData: SentryAppHang.ProfilingData,
    hub: Hub
) -> SentryEnvelope? {
    let chunkId = SentryId()
    let profileDict = profilingData.toDictionary()

    var payload: [String: Any] = [:]
    payload["version"] = "2"
    payload["chunk_id"] = chunkId.sentryIdString
    payload["profiler_id"] = profilerId.sentryIdString
    payload["platform"] = "cocoa"
    payload["profile"] = profileDict["profile"]

    let options = hub.options
    payload["environment"] = options.environment
    payload["release"] = options.releaseName

    payload["client_sdk"] = [
        "name": SentryMeta.sdkName,
        "version": SentryMeta.versionString
    ]

    let debugImages = SentryDependencyContainer.sharedInstance().debugImageProvider.getDebugImagesFromCache()
    if !debugImages.isEmpty {
        payload["debug_meta"] = [
            "images": debugImages.map { $0.serialize() }
        ]
    }

    guard let jsonData = SentrySerializationSwift.data(withJSONObject: payload) else {
        SentrySDKLog.debug("HangTrackingV3: Failed to serialize profile chunk payload to JSON")
        return nil
    }

    SentrySDKLog.debug("HangTrackingV3: Built profile_chunk envelope (chunkId=\(chunkId.sentryIdString), profilerId=\(profilerId.sentryIdString), size=\(jsonData.count) bytes)")
    let item = SentryEnvelopeItem(type: SentryEnvelopeItemTypes.profileChunk, data: jsonData, addPlatform: true)
    return SentryEnvelope(id: chunkId, singleItem: item)
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
