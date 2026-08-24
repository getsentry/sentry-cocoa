#if !SDK_V10
internal import _SentryPrivate

private final class SentryWeakBinaryImageRegistry {
    weak var value: (any SentryBinaryImageRegistry)?
}

final class SentryCrashBinaryImageProvider: SentryBinaryImageProvider {
    private static let registry = SentryMutex(SentryWeakBinaryImageRegistry())

    func start(registry: SentryBinaryImageRegistry) {
        Self.registry.withLock { $0.value = registry }
        sentrycrashbic_startCache()
        sentrycrashbic_registerAddedCallback { imagePointer in
            guard let image = imagePointer?.pointee else { return }
            guard let imageInfo = SentryBinaryImageInfo.from(
                imageName: image.name,
                vmAddress: image.vmAddress,
                address: image.address,
                size: image.size,
                uuid: image.uuid
            ) else {
                return
            }
            SentryCrashBinaryImageProvider.currentRegistry()?.binaryImageAdded(imageInfo)
        }
        sentrycrashbic_registerRemovedCallback { imagePointer in
            guard let image = imagePointer?.pointee else { return }
            SentryCrashBinaryImageProvider.currentRegistry()?.binaryImageRemoved(at: image.address)
        }
    }

    func refresh() {
        // Registering the added callback replays every image already tracked by SentryCrash.
    }

    func stop() {
        sentrycrashbic_registerAddedCallback(nil)
        sentrycrashbic_registerRemovedCallback(nil)
        sentrycrashbic_stopCache()
        Self.registry.withLock { $0.value = nil }
    }

    private static func currentRegistry() -> SentryBinaryImageRegistry? {
        registry.withLock { $0.value }
    }
}
#endif // !SDK_V10
