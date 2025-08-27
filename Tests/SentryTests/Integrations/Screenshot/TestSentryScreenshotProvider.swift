#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

@_spi(Private) @testable import Sentry

class TestSentryScreenshot: SentryViewScreenshotProvider {
    
    var result: [Data] = []
    var images: [UIImage] = []
    var processScreenshotsCallback: (() -> Void)?

    override func appScreenshotsData() -> [Data] {
        processScreenshotsCallback?()
        return result
    }
 
    override func appScreenshotsFromMainThread() -> [UIImage] {
        return images
    }
}

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
