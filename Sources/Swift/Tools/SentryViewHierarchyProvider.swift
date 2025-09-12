#if (os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS))) && !SENTRY_NO_UIKIT

@_implementationOnly import _SentryPrivate
import UIKit

@_spi(Private) @objc public class SentryViewHierarchyProvider: NSObject {
    @objc public init(dispatchQueueWrapper: SentryDispatchQueueWrapper, sentryUIApplication: SentryApplication) {
        self.reportAccessibilityIdentifier = true
        self.dispatchQueueWrapper = dispatchQueueWrapper
        self.sentryUIApplication = sentryUIApplication
    }
    
    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let sentryUIApplication: SentryApplication
    
    /**
     * Whether we should add `accessibilityIdentifier` to the view hierarchy.
     */
    @objc public var reportAccessibilityIdentifier: Bool
    
    /**
     Get the view hierarchy in a json format.
     Always runs in the main thread.
     */
    @objc public func appViewHierarchyFromMainThread() -> Data? {
        var result: Data?

        let fetchViewHierarchy = {
            result = self.appViewHierarchy()
        }

        SentrySDKLog.info("Starting to fetch the view hierarchy from the main thread.")

        dispatchQueueWrapper.dispatchSyncOnMainQueue(block: fetchViewHierarchy)

        SentrySDKLog.info("Finished fetching the view hierarchy from the main thread.")

        return result
    }
    
    @objc public func appViewHierarchy() -> Data? {
        let windows = self.sentryUIApplication.getWindows() ?? []
        return SentryViewHierarchyProviderHelper.appViewHierarchy(from: windows, reportAccessibilityIdentifier: reportAccessibilityIdentifier)
    }
    
    @discardableResult @objc(saveViewHierarchy:) public func saveViewHierarchy(_ filePath: String) -> Bool {
        let windows = sentryUIApplication.getWindows() ?? []
        return SentryViewHierarchyProviderHelper.saveViewHierarchy(filePath, windows: windows, reportAccessibilityIdentifier: reportAccessibilityIdentifier)
    }
}

#endif
