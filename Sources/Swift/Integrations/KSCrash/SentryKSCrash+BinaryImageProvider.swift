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

            // dyld owns this array and may rewrite or reallocate it when another thread loads or
            // unloads an image, so copy the entries before reading them.
            for image in copyImages() {
                publish(header: image.imageLoadAddress, name: image.imageFilePath, to: registry)
            }

            // dyld is intentionally absent from ksbic_getImages().
            publish(header: ksbic_getDyldHeader(), name: ksbic_getDyldPath(), to: registry)
        }

        private func copyImages() -> [ks_dyld_image_info] {
            var imageCount: UInt32 = 0
            guard let images = ksbic_getImages(&imageCount), imageCount > 0 else { return [] }

            // Check before Int conversion/multiplication, which can otherwise trap on arm64_32.
            let stride = MemoryLayout<ks_dyld_image_info>.stride
            guard imageCount <= UInt32(Int32.max) / UInt32(stride) else { return [] }

            let count = Int(imageCount)
            let byteCount = count * stride

            return [ks_dyld_image_info](unsafeUninitializedCapacity: count) { buffer, initializedCount in
                // If the copy fails, skip this scan and let a later refresh try again.
                // A successful copy owns the entries, not a globally stable loader snapshot.
                let copied = ksmem_copySafely(images, buffer.baseAddress, Int32(byteCount))
                initializedCount = copied ? count : 0
            }
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

            // The image can be unloaded at any point from here on, so never dereference its header
            // or name directly: copy both through vm_read and skip the image if either is gone.
            guard let name = copyName(name) else { return }

            var binaryImage = KSBinaryImage()
            var uuidBytes = [UInt8](repeating: 0, count: 16)
            let imageInfo: SentryBinaryImageInfo? = uuidBytes.withUnsafeMutableBufferPointer { uuid in
                guard let uuidStorage = uuid.baseAddress,
                      ksbic_copyTaskImage(mach_task_self_, UInt(bitPattern: header), &binaryImage, uuidStorage)
                else {
                    return nil
                }

                return name.withUnsafeBufferPointer { nameBytes in
                    SentryBinaryImageInfo.from(
                        imageName: nameBytes.baseAddress,
                        vmAddress: binaryImage.vmAddress,
                        address: binaryImage.address,
                        size: binaryImage.size,
                        uuid: binaryImage.uuid
                    )
                }
            }

            guard let imageInfo else { return }
            registry.binaryImageAdded(imageInfo)
        }

        /// Returns a NUL-terminated copy of `name`, or nil if it is unreadable or longer than `maxNameLength`.
        private func copyName(_ name: UnsafePointer<CChar>?) -> [CChar]? {
            guard let name else { return nil }

            let maxNameLength = 4_096
            var buffer = [CChar](repeating: 0, count: maxNameLength)
            let copied = Int(buffer.withUnsafeMutableBytes {
                ksmem_copyMaxPossible(name, $0.baseAddress, Int32(maxNameLength))
            })

            guard let terminator = buffer[0..<copied].firstIndex(of: 0) else { return nil }

            return Array(buffer[...terminator])
        }
    }
}
#endif // SDK_V10
