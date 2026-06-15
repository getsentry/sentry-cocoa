// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

/// Provides access to debug images for symbolication.
public struct SentryInternalDebugApi {

    private let imageProvider: SentryDebugImageProvider
    private let imageCache: SentryBinaryImageCache

    typealias Dependencies = DebugImageProvider & BinaryImageCacheProvider

    init(provider: any Dependencies) {
        self.imageProvider = provider.debugImageProvider
        self.imageCache = provider.binaryImageCache
    }

    /// All debug images currently loaded by the process.
    public var images: [DebugMeta] {
        imageProvider.getDebugImagesFromCache()
    }

    /// Debug images for the given raw memory addresses.
    public func images(forAddresses addresses: [UInt64]) -> [DebugMeta] {
        var result = [DebugMeta]()
        for address in addresses {
            guard let imageInfo = imageCache.imageByAddress(address) else { continue }
            let debugMeta = DebugMeta()
            debugMeta.imageAddress = String(format: "0x%016llx", imageInfo.address)
            debugMeta.imageSize = NSNumber(value: imageInfo.size)
            debugMeta.codeFile = imageInfo.name
            debugMeta.type = "macho"
            if let uuid = imageInfo.uuid {
                debugMeta.debugID = uuid
            }
            result.append(debugMeta)
        }
        return result
    }
}
// swiftlint:enable missing_docs
