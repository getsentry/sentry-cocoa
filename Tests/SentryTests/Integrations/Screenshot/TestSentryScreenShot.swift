#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

class TestSentryScreenshot: SentryScreenshot {
    
    var result: [Data]?
    var processViewHierarchyCallback: (() -> Void)?
        
    override func appScreenshots() -> [Data]? {
        return result
    }
 
    override func takeScreenshots() -> [Data] {
        processViewHierarchyCallback?()
        return result ?? []
    }
}

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
