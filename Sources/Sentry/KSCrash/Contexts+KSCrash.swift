import KSCrash

extension Contexts {
    static internal var serialized: SerializedType {
        let info = KSCrash.sharedInstance().systemInfo
        return [
            "os": OSContext(info).serialized,
            "device": DeviceContext(info).serialized,
            "app": AppContext(info).serialized
        ]
    }
}
