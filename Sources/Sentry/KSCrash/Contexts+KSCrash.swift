import KSCrash
import Sentry

extension Contexts {
    static internal var serialized: Event.SerializedType {
        let info = KSCrash.sharedInstance().systemInfo
        return [
            "os": OSContext(info).serialized,
            "device": DeviceContext(info).serialized,
            "app": AppContext(info).serialized
        ]
    }
}
