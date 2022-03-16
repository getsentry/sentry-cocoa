import Foundation

class SentryTestThreadWrapper: SentryThreadWrapper {
    
    override func sleep(forTimeInterval timeInterval: TimeInterval) {
        // Don't sleep. Do nothing.
    }

}
