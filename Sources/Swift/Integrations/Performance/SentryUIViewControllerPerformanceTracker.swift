#if (os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS))) && !SENTRY_NO_UIKIT

@_implementationOnly import _SentryPrivate
import UIKit

@_spi(Private) @objc public protocol SentryInitialDisplayReporting {
    func reportInitialDisplay()
}

@_spi(Private) @objc public final class SentrySwiftUISpanHelper: NSObject {
    @objc public let hasSpan: Bool
    
    @objc public func reportInitialDisplay() {
        initialDisplayReporting()
    }
    private let initialDisplayReporting: () -> Void
    
    @objc public init(hasSpan: Bool, initialDisplayReporting: @escaping () -> Void) {
        self.hasSpan = hasSpan
        self.initialDisplayReporting = initialDisplayReporting
    }
}

@_spi(Private) @objc public final class SentryUIViewControllerPerformanceTracker: NSObject {
    
    @objc private let helper: SentryDefaultUIViewControllerPerformanceTracker
    
    override init() {
        let inAppIncludes = SentrySDK.startOption?.inAppIncludes ?? []
        inAppLogic = SentryInAppLogic(inAppIncludes: inAppIncludes)
        helper = SentryDefaultUIViewControllerPerformanceTracker(tracker: SentryPerformanceTracker.shared)
    }
    
    @objc public var inAppLogic: SentryInAppLogic
    
    @objc public var alwaysWaitForFullDisplay: Bool { get {
        helper.alwaysWaitForFullDisplay
    } set {
        helper.alwaysWaitForFullDisplay = newValue
    } }
    
    @objc public func viewControllerLoadView(_ controller: UIViewController, callbackToOrigin callback: @escaping () -> Void) {
        let inAppLogic = self.inAppLogic
        helper.viewControllerLoadView(controller, isInApp: { c in
            inAppLogic.isClassInApp(c)
        }, callbackToOrigin: callback)
    }
    
    @objc public func viewControllerViewDidLoad(_ controller: UIViewController, callbackToOrigin callback: @escaping () -> Void) {
        helper.viewControllerViewDidLoad(controller, callbackToOrigin: callback)
    }
    
    @objc public func viewControllerViewWillAppear(_ controller: UIViewController, callbackToOrigin callback: @escaping () -> Void) {
        helper.viewControllerViewWillAppear(controller, callbackToOrigin: callback)
    }
    
    @objc public func viewControllerViewWillDisappear(_ controller: UIViewController, callbackToOrigin callback: @escaping () -> Void) {
        helper.viewControllerViewWillDisappear(controller, callbackToOrigin: callback)
    }

    @objc public func viewControllerViewDidAppear(_ controller: UIViewController, callbackToOrigin callback: @escaping () -> Void) {
        helper.viewControllerViewDidAppear(controller, callbackToOrigin: callback)
    }

    @objc public func viewControllerViewWillLayoutSubViews(_ controller: UIViewController, callbackToOrigin callback: @escaping () -> Void) {
        helper.viewControllerViewWillLayoutSubViews(controller, callbackToOrigin: callback)
    }

    @objc public func viewControllerViewDidLayoutSubViews(_ controller: UIViewController, callbackToOrigin callback: @escaping () -> Void) {
        helper.viewControllerViewDidLayoutSubViews(controller, callbackToOrigin: callback)
    }

    @objc public func reportFullyDisplayed() {
        helper.reportFullyDisplayed()
    }
    
    @objc public func startTimeToDisplayTracker(
        forScreen screenName: String,
        waitForFullDisplay: Bool,
        transactionId: SpanId) -> SentrySwiftUISpanHelper {
            let objcType = helper.startTimeToDisplay(forScreen: screenName, waitForFullDisplay: waitForFullDisplay, transactionId: transactionId)
            return SentrySwiftUISpanHelper(hasSpan: objcType.hasSpan) {
                objcType.reportInitialDisplay()
            }
        }
}

#endif
