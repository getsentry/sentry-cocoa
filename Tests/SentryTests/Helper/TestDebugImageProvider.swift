import Foundation

class TestDebugImageProvider: SentryDebugImageProvider {
    var debugImages: [DebugMeta]?

    override func getDebugImages() -> [DebugMeta] {
        getDebugImagesCrashed(true)
    }

    override func getDebugImagesCrashed(_ isCrash: Bool) -> [DebugMeta] {
        debugImages ?? super.getDebugImages()
    }
}
