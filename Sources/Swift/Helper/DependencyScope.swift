@objc(SentryDependencyScope) @_spi(Private) public final class DependencyScope: NSObject {
    @objc public static let dispatchQueueWrapper = SentryDispatchQueueWrapper()
    @objc public static let dateProvider = SentryDefaultCurrentDateProvider()
}
