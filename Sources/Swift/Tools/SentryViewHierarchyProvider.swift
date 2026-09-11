// swiftlint:disable missing_docs
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

internal import _SentryPrivate
import UIKit

@_spi(Private) @objc public class SentryViewHierarchyProvider: NSObject {
    @objc public init(dispatchQueueWrapper: SentryDispatchQueueWrapper, applicationProvider: @escaping () -> SentryApplication?) {
        self.reportAccessibilityIdentifier = true
        self.dispatchQueueWrapper = dispatchQueueWrapper
        self.applicationProvider = applicationProvider
    }
    
    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let applicationProvider: () -> SentryApplication?
    
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
        let windows = applicationProvider()?.getWindows() ?? []
        return SentryViewHierarchyProviderHelper.appViewHierarchy(from: windows, reportAccessibilityIdentifier: reportAccessibilityIdentifier)
    }
    
    /// Save the current view hierarchy to `filePath`.
    ///
    /// This function does not dispatch window collection to the main thread.
    /// The caller should be aware of that. Crash-time capture uses this path, and
    /// hopping to main would freeze because KSCrash has suspended other threads.
    @discardableResult @objc(saveViewHierarchy:) public func saveViewHierarchy(_ filePath: String) -> Bool {
        let windows = applicationProvider()?.collectWindowsOnCurrentThread() ?? []
        return SentryViewHierarchyProviderHelper.saveViewHierarchy(filePath, windows: windows, reportAccessibilityIdentifier: reportAccessibilityIdentifier)
    }
}

#endif
// swiftlint:enable missing_docs
