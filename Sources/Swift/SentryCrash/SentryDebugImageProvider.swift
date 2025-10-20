@_implementationOnly import _SentryPrivate

@_spi(Private) public class SentryDebugImageProvider: NSObject {
    
    @objc let helper = SentryDebugImageProviderInternal()
    
    /**
     * Returns a list of debug images that are being referenced by the given frames.
     * This function uses the @c SentryBinaryImageCache which is significantly faster than @c
     * SentryCrashDefaultBinaryImageProvider for retrieving binary image information.
     */
    @objc(getDebugImagesFromCacheForFrames:) public func getDebugImagesFromCacheForFrames(frames: [Frame]) -> [DebugMeta] {
        helper.getDebugImagesFromCacheForFrames(frames: frames)
    }

    /**
     * Returns a list of debug images that are being referenced in the given threads.
     * This function uses the @c SentryBinaryImageCache which is significantly faster than @c
     * SentryCrashDefaultBinaryImageProvider for retrieving binary image information.
     */
    @objc(getDebugImagesFromCacheForThreads:) public func getDebugImagesFromCacheForThreads(threads: [SentryThread]) -> [DebugMeta] {
        helper.getDebugImagesFromCacheForThreads(threads: threads)
    }

    /**
     * Returns a list of debug images that are being referenced in the given image addresses.
     * This function uses the @c SentryBinaryImageCache which is significantly faster than @c
     * SentryCrashDefaultBinaryImageProvider for retrieving binary image information.
     */
    @objc(getDebugImagesForImageAddressesFromCache:) public func getDebugImagesForImageAddressesFromCache(imageAddresses: Set<String>) -> [DebugMeta] {
        helper.getDebugImagesForImageAddressesFromCache(imageAddresses: imageAddresses)
    }

    @objc public func getDebugImagesFromCache() -> [DebugMeta] {
        helper.getDebugImagesFromCache()
    }
    
}
