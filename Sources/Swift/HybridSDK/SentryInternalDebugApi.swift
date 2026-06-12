// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

@_spi(Private) public final class SentryInternalDebugApi {

    /// All debug images currently loaded by the process.
    public var images: [DebugMeta] {
        SentryDependencyContainer.sharedInstance().debugImageProvider.getDebugImagesFromCache()
    }

    /// Debug images for the given raw memory addresses.
    public func images(forAddresses addresses: [UInt64]) -> [DebugMeta] {
        let cache = SentryDependencyContainer.sharedInstance().binaryImageCache
        var result = [DebugMeta]()
        for address in addresses {
            guard let imageInfo = cache.imageByAddress(address) else { continue }
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
