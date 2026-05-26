// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

public final class SentryObjCReplayOptions: NSObject {
    internal let wrapped: SentryReplayOptions

    internal init(_ wrapped: SentryReplayOptions) {
        self.wrapped = wrapped
    }

    @objc public override init() {
        self.wrapped = SentryReplayOptions()
    }

    @objc public var sessionSampleRate: Float {
        get { wrapped.sessionSampleRate }
        set { wrapped.sessionSampleRate = newValue }
    }

    @objc public var onErrorSampleRate: Float {
        get { wrapped.onErrorSampleRate }
        set { wrapped.onErrorSampleRate = newValue }
    }

    @objc public var maskAllText: Bool {
        get { wrapped.maskAllText }
        set { wrapped.maskAllText = newValue }
    }

    @objc public var maskAllImages: Bool {
        get { wrapped.maskAllImages }
        set { wrapped.maskAllImages = newValue }
    }

    @objc public var quality: SentryObjCReplayQuality {
        get { SentryObjCReplayQuality(wrapped.quality) }
        set { wrapped.quality = newValue.underlying }
    }

    @objc public var enableViewRendererV2: Bool {
        get { wrapped.enableViewRendererV2 }
        set { wrapped.enableViewRendererV2 = newValue }
    }

    @objc public var enableFastViewRendering: Bool {
        get { wrapped.enableFastViewRendering }
        set { wrapped.enableFastViewRendering = newValue }
    }

    @objc public var maskedViewClasses: [AnyClass] {
        get { wrapped.maskedViewClasses }
        set { wrapped.maskedViewClasses = newValue }
    }

    @objc public var unmaskedViewClasses: [AnyClass] {
        get { wrapped.unmaskedViewClasses }
        set { wrapped.unmaskedViewClasses = newValue }
    }

    @objc public var networkCaptureBodies: Bool {
        get { wrapped.networkCaptureBodies }
        set { wrapped.networkCaptureBodies = newValue }
    }

    @objc public var networkRequestHeaders: [String] {
        get { wrapped.networkRequestHeaders }
        set { wrapped.networkRequestHeaders = newValue }
    }

    @objc public var networkResponseHeaders: [String] {
        get { wrapped.networkResponseHeaders }
        set { wrapped.networkResponseHeaders = newValue }
    }

    @objc public func excludeViewTypeFromSubtreeTraversal(_ viewType: String) {
        wrapped.excludeViewTypeFromSubtreeTraversal(viewType)
    }

    @objc public func includeViewTypeInSubtreeTraversal(_ viewType: String) {
        wrapped.includeViewTypeInSubtreeTraversal(viewType)
    }
}

// swiftlint:enable missing_docs
