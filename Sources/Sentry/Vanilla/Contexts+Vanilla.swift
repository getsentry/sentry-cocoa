extension Contexts: EventSerializable {
    internal typealias SerializedType = SerializedTypeDictionary
    internal var serialized: SerializedType {
        return [:]
    }
}
