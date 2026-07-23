#if SDK_V10
/// Internal helper class used to access Swift-only data types related to data collection options from Objective-C
@_spi(Private) @objcMembers public final class SentryDataCollectionObjCOptions: NSObject {
    let wrapped: SentryDataCollection.Options

    /// Whether automatic user information collection is enabled.
    @_spi(Private) @objc public var userInfo: Bool {
        wrapped.userInfo
    }

    init(wrapped: SentryDataCollection.Options) {
        self.wrapped = wrapped
    }
}

extension Options {
    /// Internal bridge for resolving data collection options from Objective-C.
    @_spi(Private) @objc public var dataCollectionObjC: SentryDataCollectionObjCOptions {
        return SentryDataCollectionObjCOptions(wrapped: dataCollection)
    }
}
#endif // SDK_V10
