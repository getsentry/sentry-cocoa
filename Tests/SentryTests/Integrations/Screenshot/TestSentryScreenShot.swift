#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

class TestSentryScreenshot: SentryScreenshot {
    
    var result: [Data] = []
    var processScreenshotsCallback: (() -> Void)?
        
    override func appScreenshotsData() -> [Data] {
        processScreenshotsCallback?()
        return result
    }
 
    override func appScreenshotsFromMainThread() -> [Data] {
        return result
    }
}

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
