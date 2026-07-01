@_implementationOnly import _SentryPrivate

protocol SentryHangTrackingV3IntegrationProtocol {}

typealias SentryHangTrackingV3IntegrationDependencies = AppHangTrackerProvider & ClientProvider & ThreadInspectorProvider & DebugImageProvider & HubProvider & ExtensionDetectorProvider

final class SentryHangTrackingV3Integration<Dependencies: SentryHangTrackingV3IntegrationDependencies>: NSObject, SwiftIntegration, SentryHangTrackingV3IntegrationProtocol {

    private let appHangTracker: SentryAppHangTracker
    private let observer: SentryAppHangTrackerObserverToken

    init?(with options: Options, dependencies: Dependencies) {
        guard options.experimental.appHangs.enableV3 else {
            SentrySDKLog.debug("Not enabled, skipping installation")
            return nil
        }

        if let identifier = dependencies.extensionDetector.getExtensionPointIdentifier(), identifier.isDisabledExtensionPointIdentifier {
            SentrySDKLog.debug("Not enabling V3 hang tracking for extension: \(identifier)")
            return nil
        }

        SentrySDKLog.debug("Installing with threshold=\(options.experimental.appHangs.threshold)s")
        self.appHangTracker = dependencies.appHangTracker
        observer = appHangTracker.addObserver(threshold: options.experimental.appHangs.threshold) { hang in
            SentrySDKLog.debug("Observer callback — state=\(hang.state == .started ? "started" : "ended"), duration=\(hang.duration)s")
            guard hang.state == .ended else { return }
            guard let client = dependencies.client else {
                SentrySDKLog.debug("No client available, dropping hang event")
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
                SentrySDKLog.debug("Attaching profile (profilerId=\(profilerId.sentryIdString), hasProfilingData=\(hang.profilingData != nil))")
                Self.attachProfile(
                    to: event,
                    profilerId: profilerId,
                    profilingData: hang.profilingData,
                    hub: dependencies.hub
                )
            }

            SentrySDKLog.debug("Capturing hang event (eventId=\(event.eventId.sentryIdString))")
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
        var contexts = event.context ?? [:]
        contexts["profile"] = ["profiler_id": profilerId.sentryIdString]
        event.context = contexts

        guard let profilingData else { return }

        guard let envelope = buildProfileChunkEnvelope(profilerId: profilerId, profilingData: profilingData, hub: hub) else {
            SentrySDKLog.debug("Failed to build profile chunk envelope")
            return
        }

        hub.captureEnvelope(envelope)
    }

    func uninstall() {
        appHangTracker.removeObserver(token: observer)
    }

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
        SentrySDKLog.debug("Failed to serialize profile chunk payload to JSON")
        return nil
    }

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
            if let package = frame.package { dict["package"] = package }
            if let imageAddress = frame.imageAddress { dict["image_addr"] = imageAddress }
            if let inApp = frame.inApp { dict["in_app"] = inApp }
            return dict
        }

        let serializedStacks: [[NSNumber]] = stacks.map { stack in
            stack.map { NSNumber(value: $0) }
        }

        let serializedSamples: [[String: Any]] = samples.map { sample in
            [
                "timestamp": NSNumber(value: sample.timestamp),
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
