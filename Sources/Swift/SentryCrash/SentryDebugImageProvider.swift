// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

@_spi(Private) public class SentryDebugImageProvider: NSObject {

    private static let debugImageType = "macho"

    @objc var binaryImageCache: SentryBinaryImageCache

    @objc public override init() {
        self.binaryImageCache = Dependencies.binaryImageCache
    }

    /**
     * Returns a list of debug images that are being referenced by the given frames.
     * This function uses the @c SentryBinaryImageCache which is significantly faster than @c
     * SentryCrashDefaultBinaryImageProvider for retrieving binary image information.
     */
    @objc(getDebugImagesFromCacheForFrames:) public func getDebugImagesFromCacheForFrames(frames: [Frame]) -> [DebugMeta] {
        var imageAddresses = Set<String>()
        extractDebugImageAddresses(from: frames, into: &imageAddresses)
        return getDebugImagesForImageAddressesFromCache(imageAddresses: imageAddresses)
    }

    /**
     * Returns a list of debug images that are being referenced in the given threads.
     * This function uses the @c SentryBinaryImageCache which is significantly faster than @c
     * SentryCrashDefaultBinaryImageProvider for retrieving binary image information.
     */
    @objc(getDebugImagesFromCacheForThreads:) public func getDebugImagesFromCacheForThreads(threads: [SentryThread]) -> [DebugMeta] {
        var imageAddresses = Set<String>()

        for thread in threads {
            if let frames = thread.stacktrace?.frames {
                extractDebugImageAddresses(from: frames, into: &imageAddresses)
            }
        }

        return getDebugImagesForImageAddressesFromCache(imageAddresses: imageAddresses)
    }

    /**
     * Returns a list of debug images that are being referenced in the given image addresses.
     * This function uses the @c SentryBinaryImageCache which is significantly faster than @c
     * SentryCrashDefaultBinaryImageProvider for retrieving binary image information.
     */
    @objc(getDebugImagesForImageAddressesFromCache:) public func getDebugImagesForImageAddressesFromCache(imageAddresses: Set<String>) -> [DebugMeta] {
        var infos = [SentryBinaryImageInfo]()

        for imageAddress in imageAddresses {
            let imageAddressAsUInt64 = Self.uInt64ForHexAddress(imageAddress)
            guard let info = binaryImageCache.imageByAddress(imageAddressAsUInt64) else {
                continue
            }
            infos.append(info)
        }

        // Sort by address descending to maintain consistent ordering
        infos.sort { $0.address > $1.address }

        return infos.map { debugMeta(from: $0) }
    }

    @objc public func getDebugImagesFromCache() -> [DebugMeta] {
        let infos = binaryImageCache.getAllBinaryImages()
        return infos.map { debugMeta(from: $0) }
    }

    private func extractDebugImageAddresses(from frames: [Frame], into set: inout Set<String>) {
        for frame in frames {
            if let imageAddress = frame.imageAddress {
                set.insert(imageAddress)
            }
        }
    }

    private func debugMeta(from info: SentryBinaryImageInfo) -> DebugMeta {
        let debugMeta = DebugMeta()
        debugMeta.debugID = info.uuid
        debugMeta.type = Self.debugImageType

        if info.vmAddress > 0 {
            debugMeta.imageVmAddress = Self.formatHexAddress(info.vmAddress)
        }

        debugMeta.imageAddress = Self.formatHexAddress(info.address)
        debugMeta.imageSize = NSNumber(value: info.size)
        debugMeta.codeFile = info.name

        return debugMeta
    }

    private static func formatHexAddress(_ value: UInt64) -> String {
        return String(format: "0x%016llx", value)
    }

    private static func uInt64ForHexAddress(_ hexString: String) -> UInt64 {
        let scanner = Scanner(string: hexString)
        var value: UInt64 = 0
        if scanner.scanHexInt64(&value) {
            return value
        }
        return 0
    }
}
// swiftlint:enable missing_docs
