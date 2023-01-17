import Foundation

class TestDebugImageProvider: SentryDebugImageProvider {
    var debugImages: [DebugMeta]?

    override func getDebugImages() -> [DebugMeta] {
        return debugImages ?? super.getDebugImages()
    }
}
