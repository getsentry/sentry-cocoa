// swiftlint:disable missing_docs
internal import Sentry
import Foundation

@objc(SentryObjCExperimentalOptions) public final class SentryObjCExperimentalOptions: NSObject {
    internal let wrapped: SentryExperimentalOptions

    internal init(_ wrapped: SentryExperimentalOptions) {
        self.wrapped = wrapped
    }

    @objc public override init() {
        self.wrapped = SentryExperimentalOptions()
    }

    @objc public var metrickit: SentryObjCMetricKitOptions {
        SentryObjCMetricKitOptions(wrapped.metrickit)
    }

    @objc public var enableNewURLLoaderSwizzling: Bool {
        get { wrapped.enableNewURLLoaderSwizzling }
        set { wrapped.enableNewURLLoaderSwizzling = newValue }
    }

    @objc public var enableUIViewControllerInitSwizzling: Bool {
        get { wrapped.enableUIViewControllerInitSwizzling }
        set { wrapped.enableUIViewControllerInitSwizzling = newValue }
    }

    #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    @objc public var enableUIUpdateLinkFramesTracking: Bool {
        get { wrapped.enableUIUpdateLinkFramesTracking }
        set { wrapped.enableUIUpdateLinkFramesTracking = newValue }
    }
    #endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
}

// swiftlint:enable missing_docs
