import Foundation

class TestSentryScreenshot: SentryScreenshot {
    
    var result: [Data]?
        
    override func appScreenshots() -> [Data]? {
        return result
    }
    
}
