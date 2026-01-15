// swiftlint:disable missing_docs
import _SentryPrivate
import Foundation
@_spi(Private) @testable import Sentry

@_spi(Private) public class TestDebugImageProvider: SentryDebugImageProvider {
    public var debugImages: [DebugMeta]?
    
    public var getDebugImagesFromCacheForFramesInvocations = Invocations<Void>()
    public override func getDebugImagesFromCacheForFrames(frames: [Frame]) -> [DebugMeta] {
        getDebugImagesFromCacheForFramesInvocations.record(Void())
        
        return debugImages ?? super.getDebugImagesFromCacheForFrames(frames: frames)
    }
    
    public var getDebugImagesFromCacheForThreadsInvocations = Invocations<Void>()
    public override func getDebugImagesFromCacheForThreads(threads: [SentryThread]) -> [DebugMeta] {
        getDebugImagesFromCacheForThreadsInvocations.record(Void())
        return debugImages ?? super.getDebugImagesFromCacheForThreads(threads: threads)
    }
    
    public var getDebugImagesFromCacheInvocations = Invocations<Void>()
    public override func getDebugImagesFromCache() -> [DebugMeta] {
        getDebugImagesFromCacheInvocations.record(Void())
        return debugImages ?? super.getDebugImagesFromCache()
    }
}
// swiftlint:enable missing_docs
