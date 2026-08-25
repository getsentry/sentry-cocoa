// swiftlint:disable missing_docs
internal import _SentryPrivate
import Foundation

@objc(SentryBinaryImageInfo)
@_spi(Private) public final class SentryBinaryImageInfo: NSObject {
    @objc public var name: String
    @objc public var uuid: String?
    @objc public var vmAddress: UInt64
    @objc public var address: UInt64
    @objc public var size: UInt64

    @objc public init(name: String, uuid: String?, vmAddress: UInt64, address: UInt64, size: UInt64) {
        self.name = name
        self.uuid = uuid
        self.vmAddress = vmAddress
        self.address = address
        self.size = size
        super.init()
    }

    static func from(
        imageName: UnsafePointer<CChar>?,
        vmAddress: UInt64,
        address: UInt64,
        size: UInt64,
        uuid: UnsafePointer<UInt8>?
    ) -> SentryBinaryImageInfo? {
        guard let imageName else {
            SentrySDKLog.warning("The image name was NULL. Can't add image to cache.")
            return nil
        }
        guard let name = String(cString: imageName, encoding: .utf8) else {
            SentrySDKLog.warning("Couldn't convert the binary image name to UTF-8.")
            return nil
        }

        return SentryBinaryImageInfo(
            name: name,
            uuid: uuid.map(Self.convertUUID),
            vmAddress: vmAddress,
            address: address,
            size: size
        )
    }

    private static func convertUUID(_ value: UnsafePointer<UInt8>) -> String {
        UUID(uuid: (
            value[0], value[1], value[2], value[3],
            value[4], value[5], value[6], value[7],
            value[8], value[9], value[10], value[11],
            value[12], value[13], value[14], value[15]
        )).uuidString
    }
}

protocol SentryBinaryImageRegistry: AnyObject {
    func containsBinaryImage(at address: UInt64) -> Bool
    func binaryImageAdded(_ image: SentryBinaryImageInfo)
    func binaryImageRemoved(at address: UInt64)
}

protocol SentryBinaryImageProvider: AnyObject {
    func start(registry: SentryBinaryImageRegistry)
    func refresh()
    func stop()
}

/**
 * This class keeps a sorted collection of loaded binary images for fast frame symbolication.
 */
@objc(SentryBinaryImageCache)
@_spi(Private) public final class SentryBinaryImageCache: NSObject, SentryBinaryImageRegistry {
    @objc public internal(set) var cache: [SentryBinaryImageInfo]?
    private var isDebug: Bool = false
    // The V9 provider synchronously re-enters while registering its initial callbacks.
    private let lock = NSRecursiveLock()
    private let provider: SentryBinaryImageProvider

    @objc public override init() {
#if SDK_V10
        self.provider = SentryKSCrash.BinaryImageProvider()
#else
        self.provider = SentryCrashBinaryImageProvider()
#endif
        super.init()
    }

    init(provider: SentryBinaryImageProvider) {
        self.provider = provider
        super.init()
    }

    @objc public func start(_ isDebug: Bool) {
        lock.synchronized {
            guard cache == nil else {
                SentrySDKLog.debug("SentryBinaryImageCache is already started. Skipping start.")
                return
            }
            self.isDebug = isDebug
            self.cache = []
            provider.start(registry: self)
            provider.refresh()
        }
    }

    @objc public func stop() {
        lock.synchronized {
            guard cache != nil else {
                SentrySDKLog.debug("SentryBinaryImageCache is already stopped. Skipping stop.")
                return
            }
            provider.stop()
            self.cache = nil
        }
    }

    // We have to expand the C binary-image model because it is defined in SentryPrivate.
    @objc(binaryImageAdded:vmAddress:address:size:uuid:)
    public func binaryImageAdded(
        imageName: UnsafePointer<CChar>?,
        vmAddress: UInt64,
        address: UInt64,
        size: UInt64,
        uuid: UnsafePointer<UInt8>?
    ) {
        guard let image = SentryBinaryImageInfo.from(
            imageName: imageName,
            vmAddress: vmAddress,
            address: address,
            size: size,
            uuid: uuid
        ) else {
            return
        }
        binaryImageAdded(image)
    }

    func binaryImageAdded(_ image: SentryBinaryImageInfo) {
        let shouldValidateDuplicatedSDK = lock.synchronized { () -> Bool in
            guard let cache = self.cache else { return false }

            var left = 0
            var right = cache.count
            while left < right {
                let mid = (left + right) / 2
                if cache[mid].address < image.address {
                    left = mid + 1
                } else {
                    right = mid
                }
            }

            guard left == cache.count || cache[left].address != image.address else {
                return false
            }

            self.cache?.insert(image, at: left)
            return self.isDebug
        }

        if shouldValidateDuplicatedSDK {
            // This validation adds overhead for each class in the image, so it only runs in debug
            // mode and off the main queue.
            LoadValidator.checkForDuplicatedSDK(
                imageName: image.name,
                imageAddress: NSNumber(value: image.address),
                imageSize: NSNumber(value: image.size),
                objcRuntimeWrapper: Dependencies.objcRuntimeWrapper,
                dispatchQueueWrapper: Dependencies.dispatchQueueWrapper
            )
        }
    }

    @objc
    func binaryImageRemoved(_ imageAddress: UInt64) {
        binaryImageRemoved(at: imageAddress)
    }

    func binaryImageRemoved(at address: UInt64) {
        lock.synchronized {
            guard let index = indexOfImage(startingAt: address) else { return }
            self.cache?.remove(at: index)
        }
    }

    func containsBinaryImage(at address: UInt64) -> Bool {
        lock.synchronized {
            indexOfImage(startingAt: address) != nil
        }
    }

    @objc
    public func imageByAddress(_ address: UInt64) -> SentryBinaryImageInfo? {
        if let image = lock.synchronized({ imageContaining(address: address) }) {
            return image
        }

        provider.refresh()
        return lock.synchronized { imageContaining(address: address) }
    }

    @objc
    func getAllBinaryImages() -> [SentryBinaryImageInfo] {
        provider.refresh()
        return lock.synchronized { cache ?? [] }
    }

    private func imageContaining(address: UInt64) -> SentryBinaryImageInfo? {
        guard let index = indexOfImage(containing: address) else { return nil }
        return cache?[index]
    }

    private func indexOfImage(startingAt address: UInt64) -> Int? {
        guard let cache else { return nil }

        var left = 0
        var right = cache.count
        while left < right {
            let mid = (left + right) / 2
            if cache[mid].address < address {
                left = mid + 1
            } else {
                right = mid
            }
        }

        guard left < cache.count, cache[left].address == address else { return nil }
        return left
    }

    private func indexOfImage(containing address: UInt64) -> Int? {
        guard let cache else { return nil }

        var left = 0
        var right = cache.count - 1
        while left <= right {
            let mid = (left + right) / 2
            let image = cache[mid]

            if address >= image.address && address - image.address < image.size {
                return mid
            } else if address < image.address {
                right = mid - 1
            } else {
                left = mid + 1
            }
        }

        return nil
    }
}
// swiftlint:enable missing_docs
