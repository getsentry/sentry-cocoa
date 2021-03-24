import Foundation

class TestSentryCrashWrapper: SentryCrashAdapter {
    
    var internalCrashedLastLaunch = false
    override func crashedLastLaunch() -> Bool {
        return internalCrashedLastLaunch
    }
    
    var internalActiveDurationSinceLastCrash: TimeInterval = 0
    override func activeDurationSinceLastCrash() -> TimeInterval {
        return internalActiveDurationSinceLastCrash
    }
    
    var internalIsBeingTraced = false
    override func isBeingTraced() -> Bool {
        return internalIsBeingTraced
    }
}
