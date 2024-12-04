import _SentryPrivate
import Foundation
@testable import Sentry

public class TestDebugImageProvider: SentryDebugImageProvider {
    public var debugImages: [DebugMeta]?

    @available(*, deprecated)
    public override func getDebugImages() -> [DebugMeta] {
        getDebugImagesCrashed(true)
    }

    @available(*, deprecated)
    public override func getDebugImagesCrashed(_ isCrash: Bool) -> [DebugMeta] {
        debugImages ?? super.getDebugImagesCrashed(isCrash)
    }
    
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
