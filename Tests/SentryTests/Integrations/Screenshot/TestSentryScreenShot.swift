#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

class TestSentryScreenshot: SentryScreenshot {
    
    var result: [Data] = []
    var processViewHierarchyCallback: (() -> Void)?
        
    override func appScreenshots() -> [Data] {
        processViewHierarchyCallback?()
        return result
    }
 
    override func appScreenshotsFromMainThread() -> [Data] {
        return result
    }
}

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
