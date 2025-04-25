@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
public class SentryReplayOptions: NSObject, SentryRedactOptions {

    /**
     * Enum to define the quality of the session replay.
     */
    @objc
    public enum SentryReplayQuality: Int, CustomStringConvertible {
        fileprivate static let defaultQuality: SentryReplayQuality = .medium

        /**
         * Video Scale: 80%
         * Bit Rate: 20.000
         */
        case low

        /**
         * Video Scale: 100%
         * Bit Rate: 40.000
         */
        case medium

        /**
         * Video Scale: 100%
         * Bit Rate: 60.000
         */
        case high

        public var description: String {
            switch self {
            case .low: return "low"
            case .medium: return "medium"
            case .high: return "high"
            }
        }

        /**
         * Used by Hybrid SDKs.
         */
        static func fromName(_ name: String) -> SentryReplayOptions.SentryReplayQuality {
            switch name {
            case "low": return .low
            case "medium": return .medium
            case "high": return .high
            default: return defaultQuality
            }
        }
    }

    /**
     * Indicates the percentage in which the replay for the session will be created.
     * - Specifying @c 0 means never, @c 1.0 means always.
     * - note: The value needs to be >= 0.0 and \<= 1.0. When setting a value out of range the SDK sets it
     * to the default.
     * - note:  The default is 0.
     */
    public var sessionSampleRate: Float

    /**
     * Indicates the percentage in which a 30 seconds replay will be send with error events.
     * - Specifying 0 means never, 1.0 means always.
     * - note: The value needs to be >= 0.0 and \<= 1.0. When setting a value out of range the SDK sets it
     * to the default.
     * - note: The default is 0.
     */
    public var onErrorSampleRate: Float

    /**
     * Indicates whether session replay should redact all text in the app
     * by drawing a black rectangle over it.
     *
     * - note: The default is true
     */
    public var maskAllText = true

    /**
     * Indicates whether session replay should redact all non-bundled image
     * in the app by drawing a black rectangle over it.
     *
     * - note: The default is true
     */
    public var maskAllImages = true

    /**
     * Indicates the quality of the replay.
     * The higher the quality, the higher the CPU and bandwidth usage.
     */
    public var quality = SentryReplayQuality.defaultQuality

    /**
     * A list of custom UIView subclasses that need
     * to be masked during session replay.
     * By default Sentry already mask text and image elements from UIKit
     * Every child of a view that is redacted will also be redacted.
     */
    public var maskedViewClasses = [AnyClass]()

    /**
     * A list of custom UIView subclasses to be ignored
     * during masking step of the session replay.
     * The views of given classes will not be redacted but their children may be.
     * This property has precedence over `redactViewTypes`.
     */
    public var unmaskedViewClasses = [AnyClass]()

    /**
     * Alias for ``enableViewRendererV2``.
     *
     * This flag is deprecated and will be removed in a future version.
     * Please use ``enableViewRendererV2`` instead.
     */
    @available(*, deprecated, renamed: "enableViewRendererV2")
    public var enableExperimentalViewRenderer: Bool {
        get {
            enableViewRendererV2
        }
        set {
            enableViewRendererV2 = newValue
        }
    }

    /**
     * Enables the up to 5x faster new view renderer used by the Session Replay integration.
     *
     * Enabling this flag will reduce the amount of time it takes to render each frame of the session replay on the main thread, therefore reducing 
     * interruptions and visual lag. [Our benchmarks](https://github.com/getsentry/sentry-cocoa/pull/4940) have shown a significant improvement of
     * **up to 4-5x faster rendering** (reducing `~160ms` to `~36ms` per frame) on older devices.
     *
     * - Experiment: In case you are noticing issues with the new view renderer, please report the issue on [GitHub](https://github.com/getsentry/sentry-cocoa). 
     *               Eventually, we will remove this feature flag and use the new view renderer by default.
     */
    public var enableViewRendererV2 = true

    /**
     * Enables up to 5x faster but incommpelte view rendering used by the Session Replay integration.
     * 
     * Enabling this flag will reduce the amount of time it takes to render each frame of the session replay on the main thread, therefore reducing 
     * interruptions and visual lag. [Our benchmarks](https://github.com/getsentry/sentry-cocoa/pull/4940) have shown a significant improvement of
     * up to **5x faster render times** (reducing `~160ms` to `~30ms` per frame).
     *
     * This flag controls the way the view hierarchy is drawn into a graphics context for the session replay. By default, the view hierarchy is drawn using
     * the `UIView.drawHierarchy(in:afterScreenUpdates:)` method, which is the most complete way to render the view hierarchy. However,
     * this method can be slow, especially when rendering complex views, therefore enabling this flag will switch to render the underlying `CALayer` instead.
     *
     * - Note: This flag can only be used together with `enableViewRendererV2` with up to 20% faster render times.
     * - Warning: Rendering the view hiearchy using the `CALayer.render(in:)` method can lead to rendering issues, especially when using custom views.
     *            For complete rendering, it is recommended to set this option to `false`. In case you prefer performance over completeness, you can
     *            set this option to `true`.
     * - Experiment: This is an experimental feature and is therefore disabled by default. In case you are noticing issues with the experimental
     *               view renderer, please report the issue on [GitHub](https://github.com/getsentry/sentry-cocoa). Eventually, we will
     *               mark this feature as stable and remove the experimental flag, but will keep it disabled by default.
     */
    public var enableFastViewRendering = false

    /**
     * Defines the quality of the session replay.
     * Higher bit rates better quality, but also bigger files to transfer.
     */
    var replayBitRate: Int {
        quality.rawValue * 20_000 + 20_000
    }

    /**
     * The scale related to the window size at which the replay will be created
     */
    var sizeScale: Float {
        quality == .low ? 0.8 : 1.0
    }

    /**
     * Number of frames per second of the replay.
     * The more the havier the process is.
     * The minimum is 1, if set to zero this will change to 1.
     */
    var frameRate: UInt = 1 {
        didSet {
            if frameRate < 1 { frameRate = 1 }
        }
    }

    /**
     * The maximum duration of replays for error events.
     */
    let errorReplayDuration = TimeInterval(30)

    /**
     * The maximum duration of the segment of a session replay.
     */
    let sessionSegmentDuration = TimeInterval(5)

    /**
     * The maximum duration of a replay session.
     */
    let maximumDuration = TimeInterval(3_600)

    /**
     * Used by hybrid SDKs to be able to configure SDK info for Session Replay
     */
    var sdkInfo: [String: Any]?
    
    /**
     * Inittialize session replay options disabled
     */
    public override init() {
        self.sessionSampleRate = 0
        self.onErrorSampleRate = 0
    }

    /**
     * Initialize session replay options
     * - parameters:
     *  - sessionSampleRate Indicates the percentage in which the replay for the session will be created.
     *  - errorSampleRate Indicates the percentage in which a 30 seconds replay will be send with
     * error events.
     */
    public init(sessionSampleRate: Float = 0, onErrorSampleRate: Float = 0, maskAllText: Bool = true, maskAllImages: Bool = true, enableViewRendererV2: Bool = false, enableFastViewRendering: Bool = false) {
        self.sessionSampleRate = sessionSampleRate
        self.onErrorSampleRate = onErrorSampleRate
        self.maskAllText = maskAllText
        self.maskAllImages = maskAllImages
        self.enableViewRendererV2 = enableViewRendererV2
        self.enableFastViewRendering = enableFastViewRendering
    }

    convenience init(dictionary: [String: Any]) {
        let sessionSampleRate = (dictionary["sessionSampleRate"] as? NSNumber)?.floatValue ?? 0
        let onErrorSampleRate = (dictionary["errorSampleRate"] as? NSNumber)?.floatValue ?? 0
        let maskAllText = (dictionary["maskAllText"] as? NSNumber)?.boolValue ?? true
        let maskAllImages = (dictionary["maskAllImages"] as? NSNumber)?.boolValue ?? true
        let enableViewRendererV2 = (dictionary["enableViewRendererV2"] as? NSNumber)?.boolValue ?? (dictionary["enableExperimentalViewRenderer"] as? NSNumber)?.boolValue ?? false
        let enableFastViewRendering = (dictionary["enableFastViewRendering"] as? NSNumber)?.boolValue ?? false
        self.init(
            sessionSampleRate: sessionSampleRate,
            onErrorSampleRate: onErrorSampleRate,
            maskAllText: maskAllText,
            maskAllImages: maskAllImages,
            enableViewRendererV2: enableViewRendererV2,
            enableFastViewRendering: enableFastViewRendering
        )
        self.maskedViewClasses = ((dictionary["maskedViewClasses"] as? NSArray) ?? []).compactMap({ element in
            NSClassFromString((element as? String) ?? "")
        })
        self.unmaskedViewClasses = ((dictionary["unmaskedViewClasses"] as? NSArray) ?? []).compactMap({ element in
            NSClassFromString((element as? String) ?? "")
        })
        if let quality = SentryReplayQuality(rawValue: dictionary["quality"] as? Int ?? -1) {
            self.quality = quality
        }
        sdkInfo = dictionary["sdkInfo"] as? [String: Any]
    }
}
