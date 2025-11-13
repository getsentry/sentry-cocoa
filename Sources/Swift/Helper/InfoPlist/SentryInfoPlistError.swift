enum SentryInfoPlistError: Error, @unchecked Sendable {
    case mainInfoPlistNotFound
    case keyNotFound(key: String)
    case unableToCastValue(key: String, value: Any, type: Any.Type)
}
