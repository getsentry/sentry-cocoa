// swiftlint:disable file_length missing_docs type_body_length
import Foundation

@objcMembers
public class SentryReplayOptions: NSObject, SentryRedactOptions {
    /**
     * Default values for the session replay options.
     *
     * - Note: These values are used to ensure the different initializers use the same default values.
     */
    public class DefaultValues {
        public static let sessionSampleRate: Float = 0
        public static let onErrorSampleRate: Float = 0
        public static let maskAllText: Bool = true
        public static let maskAllImages: Bool = true
        public static let enableViewRendererV2: Bool = true
        public static let enableFastViewRendering: Bool = false
        public static let quality: SentryReplayQuality = .medium

        // The following properties are public because they are used by SentrySwiftUI.

        public static let maskedViewClasses: [AnyClass] = []
        public static let unmaskedViewClasses: [AnyClass] = []

        public static let excludedViewClasses: Set<String> = []
        public static let includedViewClasses: Set<String> = []

        // Network capture configuration defaults
        public static let networkDetailAllowUrls: [Any] = []
        public static let networkDetailDenyUrls: [Any] = []
        public static let networkCaptureBodies: Bool = true
        public static let networkRequestHeaders: [String] = ["Content-Type", "Content-Length", "Accept"]
        public static let networkResponseHeaders: [String] = ["Content-Type", "Content-Length", "Accept"]

        // The following properties are defaults which are not configurable by the user.

        fileprivate static let sdkInfo: [String: Any]? = nil
        fileprivate static let frameRate: UInt = 1
        fileprivate static let errorReplayDuration: TimeInterval = 30
        fileprivate static let sessionSegmentDuration: TimeInterval = 5
        fileprivate static let maximumDuration: TimeInterval = 60 * 60
    }

    /**
     * Enum to define the quality of the session replay.
     */
    @objc
    public enum SentryReplayQuality: Int, CustomStringConvertible {
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
            default: return DefaultValues.quality
            }
        }

        /**
         * Converts a nullable Int to a SentryReplayQuality.
         *
         * This method extends the ``SentryReplayQuality.init(rawValue:)`` by supporting nil values.
         *
         * - Parameter rawValue: The raw value to convert.
         * - Returns: Corresponding ``SentryReplayQuality`` or `nil` if not a valid raw value or no value is provided.
         */
        fileprivate static func from(rawValue: Int?) -> SentryReplayOptions.SentryReplayQuality? {
            guard let rawValue = rawValue else {
                return nil
            }
            return SentryReplayOptions.SentryReplayQuality(rawValue: rawValue)
        }

        fileprivate var bitrate: Int {
            self.rawValue * 20_000 + 20_000
        }

        fileprivate var sizeScale: Float {
            self == .low ? 0.8 : 1.0
        }
    }

    /**
     * Indicates the percentage in which the replay for the session will be created.
     *
     * - Specifying @c 0 means never, @c 1.0 means always.
     * - Note: The value needs to be `>= 0.0` and `<= 1.0`. When setting a value out of range the SDK sets it
     * to the default.
     * - Note: See ``SentryReplayOptions.DefaultValues.sessionSegmentDuration`` for the default duration of the replay.
     */
    public var sessionSampleRate: Float

    /**
     * Indicates the percentage in which a 30 seconds replay will be send with error events.
     * - Specifying 0 means never, 1.0 means always.
     *
     * - Note: The value needs to be >= 0.0 and \<= 1.0. When setting a value out of range the SDK sets it
     * to the default.
     * - Note: See ``SentryReplayOptions.DefaultValues.errorReplayDuration`` for the default duration of the replay.
     */
    public var onErrorSampleRate: Float

    /**
     * Indicates whether session replay should redact all text in the app
     * by drawing a black rectangle over it.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.maskAllText`` for the default value.
     */
    public var maskAllText: Bool

    /**
     * Indicates whether session replay should redact all non-bundled image
     * in the app by drawing a black rectangle over it.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.maskAllImages`` for the default value.
     */
    public var maskAllImages: Bool

    /**
     * Indicates the quality of the replay.
     * The higher the quality, the higher the CPU and bandwidth usage.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.quality`` for the default value.
     */
    public var quality: SentryReplayQuality

    /**
     * A list of custom UIView subclasses that need
     * to be masked during session replay.
     * By default Sentry already mask text and image elements from UIKit
     * Every child of a view that is redacted will also be redacted.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.maskedViewClasses`` for the default value.
     */
    public var maskedViewClasses: [AnyClass]

    /**
     * A list of custom UIView subclasses to be ignored
     * during masking step of the session replay.
     * The views of given classes will not be redacted but their children may be.
     * This property has precedence over `redactViewTypes`.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.unmaskedViewClasses`` for the default value.
     */
    public var unmaskedViewClasses: [AnyClass]

    /**
     * A set of view type identifier strings that should be excluded from subtree traversal.
     *
     * Views matching these types will have their subtrees skipped during redaction to avoid crashes
     * caused by traversing problematic view hierarchies (e.g., views that activate internal CoreAnimation
     * animations when their layers are accessed).
     *
     * Matching uses partial string containment: if a view's class name (from `type(of: view).description()`)
     * contains any of these strings, the subtree will be ignored. For example, "MyView" will match
     * "MyApp.MyView", "MyViewSubclass", "Some.MyView.Container", etc.
     *
     * - Note: You should use the methods ``excludeViewTypeFromSubtreeTraversal(_:)`` and ``includeViewTypeInSubtreeTraversal(_:)``
     *         to add and remove view types, so you do not accidentally remove our defaults.
     * - Note: The final set of excluded view types is computed by `SentryUIRedactBuilder` using the formula:
     *         **Default View Classes + Excluded View Classes - Included View Classes**
     *         Default view classes are defined in `SentryUIRedactBuilder` (e.g., `CameraUI.ChromeSwiftUIView` on iOS 26+).
     */
    public var excludedViewClasses: Set<String>
    
    /**
     * A set of view type identifier strings that should be included in subtree traversal.
     *
     * View types exactly matching these strings will be removed from the excluded set, allowing their subtrees
     * to be traversed even if they would otherwise be excluded by default or via `excludedViewClasses`.
     *
     * Matching uses exact string matching: the view's class name (from `type(of: view).description()`)
     * must exactly equal one of these strings. For example, "MyApp.MyView" will only match exactly "MyApp.MyView",
     * not "MyApp.MyViewSubclass".
     *
     * - Note: You should use the methods ``excludeViewTypeFromSubtreeTraversal(_:)`` and ``includeViewTypeInSubtreeTraversal(_:)``
     *         to add and remove view types, so you do not accidentally remove our defaults.
     * - Note: The final set of excluded view types is computed by `SentryUIRedactBuilder` using the formula:
     *         **Default View Classes + Excluded View Classes - Included View Classes**
     *         Default view classes are defined in `SentryUIRedactBuilder` (e.g., `CameraUI.ChromeSwiftUIView` on iOS 26+).
     *         For example, you can use this to re-enable traversal for `CameraUI.ChromeSwiftUIView` on iOS 26+
     *         by calling ``includeViewTypeInSubtreeTraversal("CameraUI.ChromeSwiftUIView")``.
     * - Note: Included patterns use exact matching (not partial) to prevent accidental matches. For example,
     *         if "ChromeCameraUI" is excluded and "Camera" is included, "ChromeCameraUI" will still be excluded
     *         because "Camera" doesn't exactly match "ChromeCameraUI".
     */
    public var includedViewClasses: Set<String>
    
    /**
     * Adds a view type pattern to the excluded set, preventing matching views' subtrees from being traversed.
     *
     * - Parameter viewType: The view type identifier pattern (as a string) to exclude from subtree traversal.
     *                      Matching uses partial string containment: if a view's class name contains this string,
     *                      the subtree will be ignored. For example, "MyView" will match "MyApp.MyView",
     *                      "MyViewSubclass", etc.
     *
     * - Note: This method adds the pattern to `excludedViewClasses`, which is then combined with
     *         default excluded types (defined in `SentryUIRedactBuilder`) and filtered by `includedViewClasses`
     *         to produce the final set.
     */
    public func excludeViewTypeFromSubtreeTraversal(_ viewType: String) {
        excludedViewClasses.insert(viewType)
    }
    
    /**
     * Adds a view type to the included set, allowing its subtree to be traversed.
     *
     * - Parameter viewType: The view type identifier (as a string) to include in subtree traversal.
     *                      Must exactly match the result of `type(of: view).description()`.
     *                      For example, "MyApp.MyView" will only match exactly "MyApp.MyView".
     *
     * - Note: This method adds the view type to `includedViewClasses`, which filters the combined set
     *         of default excluded types (defined in `SentryUIRedactBuilder`) and `excludedViewClasses`.
     *         For example, you can use this to re-enable traversal for `CameraUI.ChromeSwiftUIView` on iOS 26+.
     * - Note: Included patterns use exact matching (not partial) to prevent accidental matches.
     */
    public func includeViewTypeInSubtreeTraversal(_ viewType: String) {
        includedViewClasses.insert(viewType)
    }

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
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.enableViewRendererV2`` for the default value.
     */
    public var enableViewRendererV2: Bool

    /**
     * Enables up to 5x faster but incomplete view rendering used by the Session Replay integration.
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
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.enableFastViewRendering`` for the default value.
     */
    public var enableFastViewRendering: Bool

    /**
     * A list of URL patterns to capture request and response details for during session replay.
     * 
     * When non-empty, network requests with URLs matching any of these patterns will have their
     * headers and bodies captured for session replay.
     * 
     * Supports both String and NSRegularExpression patterns (See [JavaScript SDK](https://github.com/getsentry/sentry-javascript/blob/6fb1ee139a92a6055b52b0bbf5136fa0e5a9353f/packages/core/src/utils/string.ts#L114-L119)):
     * - String: Uses substring contains
     * - NSRegularExpression: Uses full regex matching
     * 
     * Default: empty array (network detail capture disabled)
     *
     * Example:
     * ```swift
     * // String patterns (substring matching)
     * options.sessionReplay.networkDetailAllowUrls = [
     *     "api.example.com",              // Matches any URL containing this string
     *     "/api/v1/",                      // Matches any URL containing this path
     *     "https://analytics.myapp.com"   // Matches any URL containing this prefix
     * ]
     * 
     * // NSRegularExpression patterns (full regex matching)
     * let apiRegex = try? NSRegularExpression(pattern: "^https://api\\.example\\.com/v[0-9]+/.*")
     * let imageRegex = try? NSRegularExpression(pattern: ".*\\.(jpg|jpeg|png|gif)$")
     * 
     * // Mixed array of both types
     * options.sessionReplay.networkDetailAllowUrls = [
     *     "api.example.com",               // String: substring match
     *     apiRegex!,                       // Regex: versioned API endpoints
     *     imageRegex!                      // Regex: image files
     * ]
     * ```
     *
     * - Note: Request and response bodies are truncated to 150KB maximum.
     * - Note: See ``SentryReplayOptions.DefaultValues.networkDetailAllowUrls`` for the default value.
     */
    public var networkDetailAllowUrls: [Any]

    /**
     * A list of URL patterns to exclude from network detail capture during session replay.
     * 
     * URLs matching any pattern in this array will NOT have their headers and bodies captured,
     * even if they match patterns in `networkDetailAllowUrls`. This provides fine-grained 
     * control for excluding sensitive endpoints from capture.
     * 
     * Supports both String and NSRegularExpression patterns (mirroring JavaScript SDK):
     * - String: Uses substring containment check (like JavaScript's `includes()`)
     * - NSRegularExpression: Uses full regex matching
     * 
     * Default: empty array (no URLs explicitly denied)
     *
     * Examples:
     * - String patterns: "/auth/", "/payment/", "password", ".internal."
     * - NSRegularExpression patterns: Use try NSRegularExpression(pattern:) to create regex objects
     * - Mixed arrays are supported with both types
     */
    public var networkDetailDenyUrls: [Any]

    /**
     * Whether to capture request and response bodies for allowed URLs.
     *
     * When `true` (default), bodies will be captured and parsed (JSON bodies are
     * parsed for structured display in the Sentry UI).
     *
     * When `false`, only headers and metadata will be captured for allowed URLs.
     *
     * Default: `true`
     *
     * - Note: This setting only applies when ``networkDetailAllowUrls`` is non-empty.
     * - Note: Bodies are automatically truncated to 150KB to prevent excessive memory usage.
     */
    public var networkCaptureBodies: Bool

    /**
     * Request headers to capture for allowed URLs during session replay.
     * 
     * Specifies which HTTP request headers should be captured and included in session replay
     * network details. Header matching is case-insensitive (e.g., "content-type", "Content-Type", 
     * and "CoNtEnT-tYpE" are all equivalent).
     * 
     * Default (always included): `["Content-Type", "Content-Length", "Accept"]`
     *
     * Example:
     * ```
     * options.sessionReplay.networkRequestHeaders = [
     *     "Authorization",
     *     "User-Agent"
     * ]
     * ```
     *
     * - Note: This setting only applies when ``networkDetailAllowUrls`` is non-empty.
     * - Note: Header names preserve the case seen on the request, not the case specified here.
     */
    public var networkRequestHeaders: [String] {
        get { _networkRequestHeaders }
        set { _networkRequestHeaders = Self.mergeWithDefaultHeaders(newValue, defaults: DefaultValues.networkRequestHeaders) }
    }
    private var _networkRequestHeaders: [String]

    /**
     * Response headers to capture for allowed URLs during session replay.
     * 
     * Specifies which HTTP response headers should be captured and included in session replay
     * network details. Header matching is case-insensitive (e.g., "content-type", "Content-Type", 
     * and "CoNtEnT-tYpE" are all equivalent).
     * 
     * Default (always included): `["Content-Type", "Content-Length", "Accept"]`
     *
     * Example:
     * ```
     * options.sessionReplay.networkResponseHeaders = [
     *     "Cache-Control",    // Custom header
     *     "Set-Cookie"        // Custom header
     * ]
     * ```
     *
     * - Note: This setting only applies when ``networkDetailAllowUrls`` is non-empty.
     * - Note: Header names preserve the case seen on the response, not the case specified here.
     */
    public var networkResponseHeaders: [String] {
        get { _networkResponseHeaders }
        set { _networkResponseHeaders = Self.mergeWithDefaultHeaders(newValue, defaults: DefaultValues.networkResponseHeaders) }
    }
    private var _networkResponseHeaders: [String]

    /**
     * Defines the quality of the session replay.
     *
     * Higher bit rates better quality, but also bigger files to transfer.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.quality`` for the default value.
     */
    @_spi(Private) public var replayBitRate: Int {
        quality.bitrate
    }

    /**
     * The scale related to the window size at which the replay will be created
     *
     * - Note: The scale is used to reduce the size of the replay.
     */
    @_spi(Private) public var sizeScale: Float {
        quality.sizeScale
    }

    /**
     * Number of frames per second of the replay.
     * The more the havier the process is.
     * The minimum is 1, if set to zero this will change to 1.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.frameRate`` for the default value.
     */
    @_spi(Private) public var frameRate: UInt {
        didSet {
            if frameRate < 1 {
                frameRate = 1
            }
        }
    }

    /**
     * The maximum duration of replays for error events.
     */
    @_spi(Private) public var errorReplayDuration: TimeInterval

    /**
     * The maximum duration of the segment of a session replay.
     */
    @_spi(Private) public var sessionSegmentDuration: TimeInterval

    /**
     * The maximum duration of a replay session.
     *
     * - Note: See  ``SentryReplayOptions.DefaultValues.maximumDuration`` for the default value.
     */
    @_spi(Private) public var maximumDuration: TimeInterval

    /**
     * Used by hybrid SDKs to be able to configure SDK info for Session Replay
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.sdkInfo`` for the default value.
     */
    var sdkInfo: [String: Any]?

    /**
     * Determines if network detail capture is enabled for a given URL.
     *
     * - Parameter urlString: The URL string to check
     * - Returns: `true` if network details should be captured for this URL, `false` otherwise
     */
    @objc
    public func isNetworkDetailCaptureEnabled(for urlString: String) -> Bool {
        // If allow list is empty, network detail capture is disabled
        guard !networkDetailAllowUrls.isEmpty else {
            return false
        }
        
        if matchesAnyPattern(urlString, patterns: networkDetailDenyUrls) {
            return false
        }
        
        return matchesAnyPattern(urlString, patterns: networkDetailAllowUrls)
    }
    
    /**
     * Helper method to check if a URL string matches any pattern in a list.
     *
     * Supports both String and NSRegularExpression patterns:
     * - String: Uses substring containment check (like JavaScript's includes())
     * - NSRegularExpression: Uses full regex matching
     *
     * - Parameters:
     *   - urlString: The URL string to test
     *   - patterns: Array of String or NSRegularExpression patterns
     * - Returns: `true` if the URL matches any pattern, `false` otherwise
     */
    private func matchesAnyPattern(_ urlString: String, patterns: [Any]) -> Bool {
        for pattern in patterns {
            if let stringPattern = pattern as? String {
                // String provided: substring match
                // Filter out empty strings and whitespace-only strings
                let trimmed = stringPattern.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                
                if urlString.contains(stringPattern) {
                    return true
                }
            } else if let regexPattern = pattern as? NSRegularExpression {
                // NSRegularExpression: use regex matching
                let range = NSRange(location: 0, length: urlString.utf16.count)
                if regexPattern.firstMatch(in: urlString, options: [], range: range) != nil {
                    return true
                }
            }
        }
        return false
    }
    
    /**
     * Initialize session replay options disabled
     *
     * - Note: This initializer is added for Objective-C compatibility, as constructors with default values
     *         are not supported in Objective-C.
     * - Note: See ``SentryReplayOptions.DefaultValues`` for the default values of each parameter.
     */
    public convenience override init() {
        // Setting all properties to nil will fallback to the default values in the init method.
        self.init(
            sessionSampleRate: nil,
            onErrorSampleRate: nil,
            maskAllText: nil,
            maskAllImages: nil,
            enableViewRendererV2: nil,
            enableFastViewRendering: nil,
            maskedViewClasses: nil,
            unmaskedViewClasses: nil,
            quality: nil,
            sdkInfo: nil,
            frameRate: nil,
            errorReplayDuration: nil,
            sessionSegmentDuration: nil,
            maximumDuration: nil,
            networkDetailAllowUrls: nil,
            networkDetailDenyUrls: nil,
            networkCaptureBodies: nil,
            networkRequestHeaders: nil,
            networkResponseHeaders: nil
        )
    }

    /**
     * Initializes a new instance of ``SentryReplayOptions`` using a dictionary.
     *
     * - Parameter dictionary: A dictionary containing the configuration options for the session replay.
     *
     * - Warning: This initializer is primarily used by Hybrid SDKs and is not intended for public use.
     */
    @_spi(Private) public convenience init(dictionary: [String: Any]) {
        // This initalizer is calling the one with optional parameters, so that defaults can be applied
        // for absent values.
        self.init(
            sessionSampleRate: (dictionary["sessionSampleRate"] as? NSNumber)?.floatValue,
            onErrorSampleRate: (dictionary["errorSampleRate"] as? NSNumber)?.floatValue,
            maskAllText: (dictionary["maskAllText"] as? NSNumber)?.boolValue,
            maskAllImages: (dictionary["maskAllImages"] as? NSNumber)?.boolValue,
            enableViewRendererV2: (dictionary["enableViewRendererV2"] as? NSNumber)?.boolValue
            ?? (dictionary["enableExperimentalViewRenderer"] as? NSNumber)?.boolValue,
            enableFastViewRendering: (dictionary["enableFastViewRendering"] as? NSNumber)?.boolValue,
            maskedViewClasses: (dictionary["maskedViewClasses"] as? NSArray)?.compactMap({ element in
                NSClassFromString((element as? String) ?? "")
            }),
            unmaskedViewClasses: (dictionary["unmaskedViewClasses"] as? NSArray)?.compactMap({ element in
                NSClassFromString((element as? String) ?? "")
            }),
            quality: SentryReplayQuality.from(rawValue: dictionary["quality"] as? Int),
            sdkInfo: dictionary["sdkInfo"] as? [String: Any],
            frameRate: (dictionary["frameRate"] as? NSNumber)?.uintValue,
            errorReplayDuration: (dictionary["errorReplayDuration"] as? NSNumber)?.doubleValue,
            sessionSegmentDuration: (dictionary["sessionSegmentDuration"] as? NSNumber)?.doubleValue,
            maximumDuration: (dictionary["maximumDuration"] as? NSNumber)?.doubleValue,
            excludedViewClasses: (dictionary["excludedViewClasses"] as? [String]).map { Set($0) },
            includedViewClasses: (dictionary["includedViewClasses"] as? [String]).map { Set($0) },
            networkDetailAllowUrls: dictionary["networkDetailAllowUrls"],
            networkDetailDenyUrls: dictionary["networkDetailDenyUrls"],
            networkCaptureBodies: (dictionary["networkCaptureBodies"] as? NSNumber)?.boolValue,
            networkRequestHeaders: Self.parseStringArray(from: dictionary["networkRequestHeaders"]),
            networkResponseHeaders: Self.parseStringArray(from: dictionary["networkResponseHeaders"])
        )
    }

    /**
     * Initializes a new instance of ``SentryReplayOptions`` with the specified parameters.
     *
     * - Parameters:
     *   - sessionSampleRate: Sample rate used to determine the percentage of replays of sessions that will be uploaded.
     *   - onErrorSampleRate: Sample rate used to determine the percentage of replays of error events that will be uploaded.
     *   - maskAllText: Flag to redact all text in the app by drawing a rectangle over it.
     *   - maskAllImages: Flag to redact all images in the app by drawing a rectangle over it.
     *   - enableViewRendererV2: Enables the up to 5x faster view renderer.
     *   - enableFastViewRendering: Enables faster but incomplete view rendering. See ``SentryReplayOptions.enableFastViewRendering`` for more information.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues`` for the default values of each parameter.
     */
    public convenience init(
        sessionSampleRate: Float = DefaultValues.sessionSampleRate,
        onErrorSampleRate: Float = DefaultValues.onErrorSampleRate,
        maskAllText: Bool = DefaultValues.maskAllText,
        maskAllImages: Bool = DefaultValues.maskAllImages,
        enableViewRendererV2: Bool = DefaultValues.enableViewRendererV2,
        enableFastViewRendering: Bool = DefaultValues.enableFastViewRendering
    ) {
        // - This initializer is publicly available for Swift, but not for Objective-C, because automatically bridged Swift initializers
        //   with default values result in a single initializer requiring all parameters.
        // - Each parameter has a default value, so the parameter can be omitted, which is not possible for Objective-C.
        // - Parameter values are not optional, because SDK users should not be able to set them to nil.
        // - The publicly available property `quality` is omitted in this initializer, because adding it would break backwards compatibility
        //   with the automatically bridged Objective-C initializer.
        self.init(
            sessionSampleRate: sessionSampleRate,
            onErrorSampleRate: onErrorSampleRate,
            maskAllText: maskAllText,
            maskAllImages: maskAllImages,
            enableViewRendererV2: enableViewRendererV2,
            enableFastViewRendering: enableFastViewRendering,
            maskedViewClasses: nil,
            unmaskedViewClasses: nil,
            quality: nil,
            sdkInfo: nil,
            frameRate: nil,
            errorReplayDuration: nil,
            sessionSegmentDuration: nil,
            maximumDuration: nil,
            excludedViewClasses: nil,
            includedViewClasses: nil,
            networkDetailAllowUrls: nil,
            networkDetailDenyUrls: nil,
            networkCaptureBodies: nil,
            networkRequestHeaders: nil,
            networkResponseHeaders: nil
        )
    }

    /**
     * Helper method to parse and filter string arrays from dictionary configuration.
     * 
     * Filters out non-string entries from mixed arrays while preserving valid strings.
     * Returns nil when the input is not an array type, allowing callers to fall back to defaults.
     * 
     * - Parameter value: The value from the dictionary to parse
     * - Returns: Filtered array of strings, or nil if input is not an array
     */
    private static func parseStringArray(from value: Any?) -> [String]? {
        guard let array = value as? [Any] else {
            return nil
        }
        return array.compactMap { $0 as? String }
    }
    
    /**
     * Validates developer-provided NetworkDetail URL patterns and returns a subset of only valid entries.
     * 
     * Accepts both String and NSRegularExpression objects.
     * Filters out invalid entries and preserves valid patterns.
     * Filters out empty strings and whitespace-only strings.
     * 
     * - Parameter value: The value from the dictionary to parse
     * - Returns: Filtered array of String and NSRegularExpression patterns, or nil if input is not an array
     */
    private static func validateNetworkDetailUrlPatterns(from value: Any?) -> [Any]? {
        guard let array = value as? [Any] else {
            if let nonNilValue = value {
                SentrySDKLog.log(message: "Invalid networkDetail URL pattern configuration: expected array, got \(type(of: nonNilValue))", 
                               andLevel: .warning)
            }
            return nil
        }
        
        var validPatterns: [Any] = []
        var invalidCount = 0
        
        for (index, element) in array.enumerated() {
            if let stringElement = element as? String {
                // Filter out empty strings and whitespace-only strings
                let trimmed = stringElement.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    SentrySDKLog.log(message: "Invalid networkDetail URL pattern at index \(index): empty or whitespace-only string discarded", 
                                   andLevel: .warning)
                    invalidCount += 1
                } else {
                    validPatterns.append(stringElement)
                }
            } else if let regexElement = element as? NSRegularExpression {
                validPatterns.append(regexElement)
            } else {
                SentrySDKLog.log(message: "Invalid networkDetail URL pattern at index \(index): expected String or NSRegularExpression, got \(type(of: element))", 
                               andLevel: .warning)
                invalidCount += 1
            }
        }
        
        if invalidCount > 0 {
            SentrySDKLog.log(message: "NetworkDetail URL patterns: \(invalidCount) invalid entries discarded, \(validPatterns.count) valid patterns retained", 
                           andLevel: .info)
        }
        
        return validPatterns
    }

    // swiftlint:disable:next function_parameter_count cyclomatic_complexity
    private init(
        sessionSampleRate: Float?,
        onErrorSampleRate: Float?,
        maskAllText: Bool?,
        maskAllImages: Bool?,
        enableViewRendererV2: Bool?,
        enableFastViewRendering: Bool?,
        maskedViewClasses: [AnyClass]?,
        unmaskedViewClasses: [AnyClass]?,
        quality: SentryReplayQuality?,
        sdkInfo: [String: Any]?,
        frameRate: UInt?,
        errorReplayDuration: TimeInterval?,
        sessionSegmentDuration: TimeInterval?,
        maximumDuration: TimeInterval?,
        excludedViewClasses: Set<String>? = nil,
        includedViewClasses: Set<String>? = nil,
        networkDetailAllowUrls: Any? = nil,
        networkDetailDenyUrls: Any? = nil,
        networkCaptureBodies: Bool? = nil,
        networkRequestHeaders: [String]? = nil,
        networkResponseHeaders: [String]? = nil
    ) {
        self.sessionSampleRate = sessionSampleRate ?? DefaultValues.sessionSampleRate
        self.onErrorSampleRate = onErrorSampleRate ?? DefaultValues.onErrorSampleRate
        self.maskAllText = maskAllText ?? DefaultValues.maskAllText
        self.maskAllImages = maskAllImages ?? DefaultValues.maskAllImages
        self.enableViewRendererV2 = enableViewRendererV2 ?? DefaultValues.enableViewRendererV2
        self.enableFastViewRendering = enableFastViewRendering ?? DefaultValues.enableFastViewRendering
        self.maskedViewClasses = maskedViewClasses ?? DefaultValues.maskedViewClasses
        self.unmaskedViewClasses = unmaskedViewClasses ?? DefaultValues.unmaskedViewClasses
        self.quality = quality ?? DefaultValues.quality
        self.sdkInfo = sdkInfo ?? DefaultValues.sdkInfo
        self.frameRate = frameRate ?? DefaultValues.frameRate
        self.errorReplayDuration = errorReplayDuration ?? DefaultValues.errorReplayDuration
        self.sessionSegmentDuration = sessionSegmentDuration ?? DefaultValues.sessionSegmentDuration
        self.maximumDuration = maximumDuration ?? DefaultValues.maximumDuration
        self.excludedViewClasses = excludedViewClasses ?? DefaultValues.excludedViewClasses
        self.includedViewClasses = includedViewClasses ?? DefaultValues.includedViewClasses
        self.networkDetailAllowUrls = Self.validateNetworkDetailUrlPatterns(from: networkDetailAllowUrls) ?? DefaultValues.networkDetailAllowUrls
        self.networkDetailDenyUrls = Self.validateNetworkDetailUrlPatterns(from: networkDetailDenyUrls) ?? DefaultValues.networkDetailDenyUrls
        self.networkCaptureBodies = networkCaptureBodies ?? DefaultValues.networkCaptureBodies
        self._networkRequestHeaders = Self.mergeWithDefaultHeaders(networkRequestHeaders, defaults: DefaultValues.networkRequestHeaders)
        self._networkResponseHeaders = Self.mergeWithDefaultHeaders(networkResponseHeaders, defaults: DefaultValues.networkResponseHeaders)

        super.init()
    }
    
    /**
     * Merges user-provided headers with default headers, ensuring defaults are always included.
     *
     * - Parameter userHeaders: Headers specified by the user (can be nil)
     * - Parameter defaults: Default headers that must always be included
     * - Returns: Array containing both user headers and default headers (with duplicates removed)
     */
    private static func mergeWithDefaultHeaders(_ userHeaders: [String]?, defaults: [String]) -> [String] {
        let providedHeaders = userHeaders ?? []
        
        // Use Set to remove duplicates, then convert back to Array
        // Case-insensitive comparison to avoid duplicate headers with different casing
        var seenHeaders = Set<String>()
        var result: [String] = []
        
        // Add default headers first
        for header in defaults {
            let lowercased = header.lowercased()
            if !seenHeaders.contains(lowercased) {
                seenHeaders.insert(lowercased)
                result.append(header)
            }
        }
        
        // Add user-provided headers
        for header in providedHeaders {
            let lowercased = header.lowercased()
            if !seenHeaders.contains(lowercased) {
                seenHeaders.insert(lowercased)
                result.append(header)
            }
        }
        
        return result
    }
}
// swiftlint:enable file_length missing_docs type_body_length
