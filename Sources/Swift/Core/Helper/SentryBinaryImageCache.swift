// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
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
}

/**
 * This class listens to `SentryCrashBinaryImageCache` to keep a copy of the loaded binaries
 * information in a sorted collection that will be used to symbolicate frames with better
 * performance.
 */
@objc(SentryBinaryImageCache)
@_spi(Private) public final class SentryBinaryImageCache: NSObject {
    private var cache: [SentryBinaryImageInfo]?
    private var isDebug: Bool = false
    private let lock = NSLock()
    /// When true, `cache` has unsorted appends and must be sorted before binary search.
    private var needsSort: Bool = false
    
    @objc public func start(_ isDebug: Bool) {
        lock.synchronized {
            self.isDebug = isDebug
            self.cache = []
            self.needsSort = false
        }
        
        // Register callbacks outside the lock — they acquire it independently.
        sentrycrashbic_registerAddedCallback { imagePtr in
            guard let imagePtr else {
                SentrySDKLog.warning("The image is NULL. Can't add NULL to cache.")
                return
            }
            let image = imagePtr.pointee
            SentryDependencyContainer.sharedInstance().binaryImageCache.binaryImageAdded(
                imageName: image.name, vmAddress: image.vmAddress, address: image.address, size: image.size, uuid: image.uuid)
        }
        sentrycrashbic_registerRemovedCallback { imagePtr in
            guard let imagePtr else {
                SentrySDKLog.warning("The image is NULL. Can't add NULL to cache.")
                return
            }
            let image = imagePtr.pointee
            SentryDependencyContainer.sharedInstance().binaryImageCache.binaryImageRemoved(image.address)
        }
    }
    
    @objc public func stop() {
        sentrycrashbic_registerAddedCallback(nil)
        sentrycrashbic_registerRemovedCallback(nil)
        lock.synchronized {
            self.cache = nil
            self.needsSort = false
        }
    }
    
    // We have to expand `SentryCrashBinaryImage` since the model is defined in SentryPrivate
    @objc(binaryImageAdded:vmAddress:address:size:uuid:)
    public func binaryImageAdded(imageName: UnsafePointer<CChar>?,
                                 vmAddress: UInt64,
                                 address: UInt64,
                                 size: UInt64,
                                 uuid: UnsafePointer<UInt8>?) {
        guard let imageName else {
            SentrySDKLog.warning("The image name was NULL. Can't add image to cache.")
            return
        }
        guard let nameString = String(cString: imageName, encoding: .utf8) else {
            SentrySDKLog.warning("Couldn't convert the cString image name to an NSString. This could be due to a different encoding than NSUTF8StringEncoding of the cString..")
            return
        }
        
        let newImage = SentryBinaryImageInfo(
            name: nameString,
            uuid: Self.convertUUID(uuid),
            vmAddress: vmAddress,
            address: address,
            size: size
        )
        
        var shouldValidate = false
        lock.synchronized {
            guard self.cache != nil else { return }
            
            // O(1) append — sorting is deferred until a lookup or removal needs it.
            self.cache?.append(newImage)
            self.needsSort = true
            shouldValidate = self.isDebug
        }
        
        if shouldValidate {
            // This validation adds some overhead with each class present in the image, so we only
            // run this when debug is enabled. A non main queue is used to avoid affecting the UI.
            LoadValidator.checkForDuplicatedSDK(imageName: nameString,
                                                imageAddress: NSNumber(value: newImage.address),
                                                imageSize: NSNumber(value: newImage.size),
                                                objcRuntimeWrapper: Dependencies.objcRuntimeWrapper,
                                                dispatchQueueWrapper: Dependencies.dispatchQueueWrapper)
        }
    }
    
    @objc
    public static func convertUUID(_ value: UnsafePointer<UInt8>?) -> String? {
        guard let value = value else { return nil }
        
        var uuidBuffer = [CChar](repeating: 0, count: 37)
        sentrycrashdl_convertBinaryImageUUID(value, &uuidBuffer)
        return String(cString: uuidBuffer, encoding: .ascii)
    }
    
    @objc
    public func binaryImageRemoved(_ imageAddress: UInt64) {
        lock.synchronized {
            sortIfNeeded()
            guard let index = indexOfImage(address: imageAddress) else { return }
            self.cache?.remove(at: index)
        }
    }
    
    @objc
    public func imageByAddress(_ address: UInt64) -> SentryBinaryImageInfo? {
        lock.synchronized {
            sortIfNeeded()
            guard let index = indexOfImage(address: address) else { return nil }
            return cache?[index]
        }
    }
    
    /// Sorts the cache if new elements have been appended since the last sort.
    /// Must be called while holding `lock`.
    private func sortIfNeeded() {
        guard needsSort else { return }
        self.cache?.sort { $0.address < $1.address }
        needsSort = false
    }
    
    private func indexOfImage(address: UInt64) -> Int? {
        guard let cache = self.cache else { return nil }
        
        var left = 0
        var right = cache.count - 1
        
        while left <= right {
            let mid = (left + right) / 2
            let image = cache[mid]
            
            if address >= image.address && address < (image.address + image.size) {
                return mid
            } else if address < image.address {
                right = mid - 1
            } else {
                left = mid + 1
            }
        }
        
        return nil
    }
    
    @objc(imagePathsForInAppInclude:)
    public func imagePathsFor(inAppInclude: String) -> Set<String> {
        lock.synchronized {
            // No sort needed — this iterates all entries regardless of order.
            var imagePaths = Set<String>()
            
            guard let cache = self.cache else { return imagePaths }
            
            for info in cache {
                if SentryInAppLogic.isImageNameInApp(info.name, inAppInclude: inAppInclude) {
                    imagePaths.insert(info.name)
                }
            }
            return imagePaths
        }
    }
    
    @objc
    public func getAllBinaryImages() -> [SentryBinaryImageInfo] {
        lock.synchronized {
            sortIfNeeded()
            return cache ?? []
        }
    }   
}
// swiftlint:enable missing_docs
