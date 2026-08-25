#if SDK_V10
internal import KSCrashRecordingCore

private final class SentryKSCrashWeakBinaryImageRegistry {
    weak var value: (any SentryBinaryImageRegistry)?
}

extension SentryKSCrash {
    final class BinaryImageProvider: SentryBinaryImageProvider {
        private let registry = SentryMutex(SentryKSCrashWeakBinaryImageRegistry())

        func start(registry: SentryBinaryImageRegistry) {
            self.registry.withLock { $0.value = registry }
            // Sentry clients need binary images even when the crash integration is disabled.
            // KSCrash installation calls this again safely when the integration is enabled.
            ksdl_init()
        }

        func refresh() {
            guard let registry = registry.withLock({ $0.value }) else { return }

            var imageCount: UInt32 = 0
            if let images = ksbic_getImages(&imageCount) {
                for index in 0..<Int(imageCount) {
                    publish(
                        header: images[index].imageLoadAddress,
                        name: images[index].imageFilePath,
                        to: registry
                    )
                }
            }

            // dyld is intentionally absent from ksbic_getImages().
            publish(header: ksbic_getDyldHeader(), name: ksbic_getDyldPath(), to: registry)
        }

        func stop() {
            // KSCrash owns its process-lifetime cache. Stop only disconnects this SDK cache.
            registry.withLock { $0.value = nil }
        }

        private func publish(
            header: UnsafePointer<mach_header>?,
            name: UnsafePointer<CChar>?,
            to registry: SentryBinaryImageRegistry
        ) {
            guard let header else { return }
            let address = UInt64(UInt(bitPattern: header))
            guard !registry.containsBinaryImage(at: address) else { return }

            var binaryImage = KSBinaryImage()
            guard ksdl_binaryImageForHeader(header, name, &binaryImage) else { return }
            guard let imageInfo = SentryBinaryImageInfo.from(
                imageName: binaryImage.name,
                vmAddress: binaryImage.vmAddress,
                address: binaryImage.address,
                size: binaryImage.size,
                uuid: binaryImage.uuid
            ) else {
                return
            }
            registry.binaryImageAdded(imageInfo)
        }
    }
}
#endif // SDK_V10
