import KSCrash

extension Contexts: EventSerializable {
    internal typealias SerializedType = SerializedTypeDictionary
    internal var serialized: SerializedType {
        let info = KSCrash.sharedInstance().systemInfo
        return [
            "os": OSContext(info).serialized,
            "device": DeviceContext(info).serialized,
            "app": AppContext(info).serialized
        ]
    }
}
