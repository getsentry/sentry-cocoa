import DeviceActivity
import ManagedSettings
import SentrySampleShared

class DeviceActivityMonitorExtension: DeviceActivityMonitor {    
    override init() {
        super.init()
        SentrySDKWrapper.shared.startSentry()
    }
} 
