protocol SentryInfoPlistWrapperProvider {
    /// Retrieves a value from the app's `Info.plist` file for the given key and tries to cast it to a `String`.
    ///
    /// - Parameter key: The key for which to retrieve the value from the `Info.plist`.
    /// - Throws: An error if the value cannot be cast to type `String` or `SentryInfoPlistError.keyNotFound` if the key was not found or the value is `nil`
    /// - Returns: The value associated with the specified key cast to type `String`
    /// - Note: The return value can not be nullable, because a throwing function in Objective-C uses `nil` to indicate an error:
    ///
    ///       Throwing method cannot be a member of an '@objc' protocol because it returns a value of optional type 'String?'; 'nil' indicates failure to Objective-C
    func getAppValueString(for key: String) throws -> String

    /// Retrieves a value from the app's `Info.plist` file for the given key and tries to cast it to a `Bool`.
    ///
    /// - Parameters:
    ///   - key: The key for which to retrieve the value from the `Info.plist`.
    ///   - errorPtr: A pointer to an `NSError` to return an error value.
    /// - Returns: The value associated with the specified key cast to type `Bool`
    /// - Note: This method can not use `throws` because a falsy return value would indicate an error in Objective-C:
    ///
    ///       Throwing method cannot be a member of an '@objc' protocol because it returns a value of type 'Bool'; return 'Void' or a type that bridges to an Objective-C class
    func getAppValueBoolean(for key: String, errorPtr: NSErrorPointer) -> Bool

    /// Retrieves a value from the app's `Info.plist` file for the given key and tries to cast it to a `[String: Any]` dictionary.
    ///
    /// - Parameter key: The key for which to retrieve the value from the `Info.plist`.
    /// - Throws: An error if the value cannot be cast to type `[String: Any]` or `SentryInfoPlistError.keyNotFound` if the key was not found or the value is `nil`
    /// - Returns: The value associated with the specified key cast to type `[String: Any]`
    /// - Note: The return value can not be nullable, because a throwing function in Objective-C uses `nil` to indicate an error:
    ///
    ///       Throwing method cannot be a member of an '@objc' protocol because it returns a value of optional type '[String: Any]?'; 'nil' indicates failure to Objective-C
    func getAppValueDictionary(for key: String) throws -> [String: Any]
}
