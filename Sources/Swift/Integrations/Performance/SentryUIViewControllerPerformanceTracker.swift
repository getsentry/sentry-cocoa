#if (os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS))) && !SENTRY_NO_UIKIT

import UIKit

@_spi(Private) @objc public protocol SentryInitialDisplayReporting {
    func reportInitialDisplay()
}

@_spi(Private) @objc public class SentrySwiftUISpanHelper: NSObject {
    @objc public let hasSpan: Bool
    @objc public let initialDisplayReporting: SentryInitialDisplayReporting?
    
    @objc public init(hasSpan: Bool, initialDisplayReporting: SentryInitialDisplayReporting?) {
        self.hasSpan = hasSpan
        self.initialDisplayReporting = initialDisplayReporting
    }
}

@_spi(Private) @objc public protocol SentryUIViewControllerPerformanceTracker {
    
    var inAppLogic: SentryInAppLogic { get set }
    
    var alwaysWaitForFullDisplay: Bool { get set }
    
    func viewControllerLoadView(_ controller: UIViewController, callbackToOrigin callback: @escaping () -> Void)
    
    func viewControllerViewDidLoad(_ controller: UIViewController, callbackToOrigin callback: @escaping () -> Void)
    
    func viewControllerViewWillAppear(_ controller: UIViewController, callbackToOrigin callback: @escaping () -> Void)
    
    func viewControllerViewWillDisappear(_ controller: UIViewController, callbackToOrigin callback: @escaping () -> Void)

    func viewControllerViewDidAppear(_ controller: UIViewController, callbackToOrigin callback: @escaping () -> Void)

    func viewControllerViewWillLayoutSubViews(_ controller: UIViewController, callbackToOrigin callback: @escaping () -> Void)

    func viewControllerViewDidLayoutSubViews(_ controller: UIViewController, callbackToOrigin callback: @escaping () -> Void)

    func reportFullyDisplayed()
    
    func startTimeToDisplayTracker(
        forScreen screenName: String,
        waitForFullDisplay: Bool,
        transactionId: SpanId) -> SentrySwiftUISpanHelper
}

#endif
