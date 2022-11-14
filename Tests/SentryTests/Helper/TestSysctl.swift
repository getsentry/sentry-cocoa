import Foundation

class TestSysctl: SentrySysctl {
    
    private var internalSystemBootTimestamp: Date = Date(timeIntervalSinceReferenceDate: 0)
    
    override var systemBootTimestamp: Date {
        return internalSystemBootTimestamp
    }
    
    public func setSystemUpTime(value: Date) {
        internalSystemBootTimestamp = value
    }
    
    private var internalProcessStartTimestamp: Date = Date(timeIntervalSinceReferenceDate: 0)
    
    override var processStartTimestamp: Date {
        return internalProcessStartTimestamp
    }
    
    public func setProcessStartTimestamp(value: Date) {
        internalProcessStartTimestamp = value
    }
    
    private var internalModuleInitializationTimestamp: Date = Date(timeIntervalSinceReferenceDate: 0)
    
    override var moduleInitializationTimestamp: Date {
        return internalModuleInitializationTimestamp
    }
    
    public func setModuleInitializationTimestamp(value: Date) {
        internalModuleInitializationTimestamp = value
    }
}
