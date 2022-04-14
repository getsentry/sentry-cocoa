import Foundation

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class TestSentryScreenshot: SentryScreenshot {
    
    var result: [Data]?
        
    override func appScreenshots() -> [Data]? {
        return result
    }
    
}
#endif
