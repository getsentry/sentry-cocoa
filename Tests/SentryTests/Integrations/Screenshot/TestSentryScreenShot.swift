import Foundation


class TestSentryScreenshot  : SentryScreenshot {
    
    var result : [Data]? = nil
        
    override func appScreenshots() -> [Data]? {
        return result
    }
    
}
