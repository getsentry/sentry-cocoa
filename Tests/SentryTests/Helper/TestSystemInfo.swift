import Foundation

class TestSystemInfo: SentrySystemInfo {
    
    private var internalSystemBootTimestamp: Date = Date(timeIntervalSinceReferenceDate: 0)
    
    override var systemBootTimestamp: Date {
        return internalSystemBootTimestamp
    }
    
    public func setSystemUpTime(value: Date) {
        internalSystemBootTimestamp = value
    }
    
}
