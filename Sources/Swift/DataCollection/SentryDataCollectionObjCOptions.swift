#if SDK_V10
/// Internal helper class used to access Swift-only data types related to data collection options from Objective-C
@_spi(Private) @objcMembers public final class SentryDataCollectionObjCOptions: NSObject {
    let wrapped: SentryDataCollection.Options

    init(wrapped: SentryDataCollection.Options) {
        self.wrapped = wrapped
    }
}

extension Options {
    /// Internal bridge for resolving data collection options from Objective-C.
    @_spi(Private) @objc public var dataCollectionObjC: SentryDataCollectionObjCOptions {
        let urlQueryParams = sendDefaultPii
            ? dataCollection.urlQueryParams
            : .denyList(terms: ["forwarded", "-ip", "remote-", "via", "-user"])

        return SentryDataCollectionObjCOptions(
            wrapped: SentryDataCollection.Options(urlQueryParams: urlQueryParams)
        )
    }
}
#endif // SDK_V10
