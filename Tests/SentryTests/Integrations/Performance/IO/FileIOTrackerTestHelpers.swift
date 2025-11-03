@_spi(Private) @testable import Sentry

@objc public class FileIOTrackerTestHelpers: NSObject {
    @objc static func makeTracker(options: Options) -> SentryFileIOTracker {
        let threadInspector = SentryThreadInspector(options: options.toInternal())
        let processInfoWrapper = SentryDependencyContainer.sharedInstance().processInfoWrapper
        return SentryFileIOTracker(threadInspector: threadInspector, processInfoWrapper: processInfoWrapper)
    }
}
