import Foundation
import SentryTestUtils

class TestDebugImageProvider: SentryDebugImageProvider {
    var debugImages: [DebugMeta]?

    override func getDebugImages() -> [DebugMeta] {
        getDebugImagesCrashed(true)
    }

    override func getDebugImagesCrashed(_ isCrash: Bool) -> [DebugMeta] {
        debugImages ?? super.getDebugImagesCrashed(isCrash)
    }
    
    var getDebugImagesFromCacheForFramesInvocations = Invocations<Void>()
    override func getDebugImagesFromCacheForFrames(frames: [Frame]) -> [DebugMeta] {
        getDebugImagesFromCacheForFramesInvocations.record(Void())
        
        return debugImages ?? super.getDebugImagesFromCacheForFrames(frames: frames)
    }
    
    var getDebugImagesFromCacheForThreadsInvocations = Invocations<Void>()
    override func getDebugImagesFromCacheForThreads(threads: [SentryThread]) -> [DebugMeta] {
        getDebugImagesFromCacheForThreadsInvocations.record(Void())
        return debugImages ?? super.getDebugImagesFromCacheForThreads(threads: threads)
    }
}
