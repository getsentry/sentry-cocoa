#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

class TestSentryScreenshot: SentryScreenshot {
    
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
