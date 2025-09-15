enum SentryMsgPackSerializerError: Error {
    case dictionaryTooLarge
    case invalidValue(String)
    case invalidInput(String)
    case emptyData(String)
    case streamError(String)
    case outputError(String)
}
