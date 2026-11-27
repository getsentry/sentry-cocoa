// swiftlint:disable missing_docs
internal import Sentry
import Foundation

@objc(SentryObjCReplayOptions) public final class SentryObjCReplayOptions: NSObject {
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

}

// swiftlint:enable missing_docs
