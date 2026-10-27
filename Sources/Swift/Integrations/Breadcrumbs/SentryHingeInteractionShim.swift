internal import _SentryPrivate

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

/// Creates `UIHingeInteraction` instances for `SentryHingeObserver`.
///
/// `UIHingeInteraction` and `UIHinge` only exist in the iOS 27.1 SDK, which is newer than the oldest
/// Xcode this SDK supports. When Sentry is compiled with the iOS 27.1 SDK or later, such as with
/// SwiftPM and Xcode 27.1, `SentryNativeHingeInteractionShim` references the API directly. Otherwise,
/// such as for the prebuilt XCFramework, `SentryRuntimeHingeInteractionShim` looks the class up
/// through the Objective-C runtime, so the feature still works on devices running iOS 27.1 or later.
protocol SentryHingeInteractionShim {
    /// Whether the current runtime provides `UIHingeInteraction`.
    var isAvailable: Bool { get }

    /// Creates a hinge interaction that calls `updateHandler` with every hinge update. A nil state
    /// means the interaction left a hierarchy that provides hinge updates.
    func makeInteraction(updateHandler: @escaping (SentryHingeState?) -> Void) -> UIInteraction?
}

enum SentryHingeInteractionShims {
    /// The native shim when compiled with the iOS 27.1 SDK and running on iOS 27.1 or later,
    /// otherwise the runtime shim.
    static func make() -> SentryHingeInteractionShim {
        #if canImport(SwiftUI, _version: 8.0.85)
        if #available(iOS 27.1, *) {
            return SentryNativeHingeInteractionShim()
        }
        #endif
        return SentryRuntimeHingeInteractionShim()
    }
}

// Xcode 27.0 and Xcode 27.1 both ship Swift 6.4, so `#if compiler(>=6.4)` cannot tell their SDKs
// apart. The SwiftUI module version can: the iOS 27.0 SDK ships SwiftUI 8.0.84 and the iOS 27.1 SDK
// ships SwiftUI 8.0.85, and the Mac Catalyst SDK of Xcode 27.1 still ships 8.0.84 together with the
// iOS 27.0 UIKit. SwiftUI is checked instead of UIKit because it is a pure Swift module, whose
// version is always readable, while the Clang module version of UIKit is not available in every
// build configuration. This gate is repeated in `SentryHingeInteractionShimTests`, because Swift
// cannot define a compilation condition from source.
#if canImport(SwiftUI, _version: 8.0.85)

extension SentryHingeStatus {
    @available(iOS 27.1, *)
    init(_ status: UIHinge.Status) {
        switch status {
        case .unknown: self = .unknown
        case .closed: self = .closed
        case .partiallyOpen: self = .partiallyOpen
        case .fullyOpen: self = .fullyOpen
        @unknown default: self = .unknown
        }
    }
}

/// References `UIHingeInteraction` directly, which requires the iOS 27.1 SDK at compile time.
@available(iOS 27.1, *)
struct SentryNativeHingeInteractionShim: SentryHingeInteractionShim {
    var isAvailable: Bool { true }

    func makeInteraction(updateHandler: @escaping (SentryHingeState?) -> Void) -> UIInteraction? {
        UIHingeInteraction { _, update in
            updateHandler(update.hinge.map { SentryHingeState(status: SentryHingeStatus($0.status), angle: $0.angle) })
        }
    }
}

#endif // canImport(SwiftUI, _version: 8.0.85)

/// Creates `UIHingeInteraction` through the Objective-C runtime, for builds without the iOS 27.1 SDK.
struct SentryRuntimeHingeInteractionShim: SentryHingeInteractionShim {
    private static let initSelector = NSSelectorFromString("initWithUpdateHandler:")
    private static let hingeSelector = NSSelectorFromString("hinge")
    private static let statusSelector = NSSelectorFromString("status")
    private static let angleSelector = NSSelectorFromString("angle")

    private let className: String

    /// - Parameter className: The interaction class to look up. Only tests pass a different class.
    init(className: String = "UIHingeInteraction") {
        self.className = className
    }

    var isAvailable: Bool {
        interactionClass != nil
    }

    private var interactionClass: NSObject.Type? {
        guard let interactionClass = NSClassFromString(className) as? NSObject.Type,
              interactionClass.instancesRespond(to: Self.initSelector) else {
            return nil
        }
        return interactionClass
    }

    func makeInteraction(updateHandler: @escaping (SentryHingeState?) -> Void) -> UIInteraction? {
        guard let interactionClass else {
            return nil
        }

        // The handler signature is (UIHingeInteraction *, UIHingeInteractionUpdate *).
        let handler: @convention(block) (AnyObject, AnyObject) -> Void = { _, update in
            updateHandler(Self.hingeState(from: update))
        }
        let handlerBlock = unsafeBitCast(handler, to: AnyObject.self)

        // `alloc` returns a +1 reference that `initWithUpdateHandler:` consumes, and init returns a
        // +1 reference that we take ownership of. Taking the alloc result unretained keeps the
        // retain counts balanced even if init returns a different object.
        guard let allocated = (interactionClass as AnyObject).perform(NSSelectorFromString("alloc"))?.takeUnretainedValue(),
              let interaction = allocated.perform(Self.initSelector, with: handlerBlock)?.takeRetainedValue() else {
            return nil
        }
        return interaction as? UIInteraction
    }

    /// Reads the `hinge` of a `UIHingeInteractionUpdate` through key-value coding.
    ///
    /// Every key is guarded with `responds(to:)` first, because an undefined key raises an
    /// Objective-C exception that Swift cannot catch.
    static func hingeState(from update: AnyObject) -> SentryHingeState? {
        guard let update = update as? NSObject,
              update.responds(to: hingeSelector),
              let hinge = update.value(forKey: "hinge") as? NSObject,
              hinge.responds(to: statusSelector),
              hinge.responds(to: angleSelector),
              let rawStatus = hinge.value(forKey: "status") as? Int,
              let angle = hinge.value(forKey: "angle") as? Double else {
            return nil
        }
        let status = SentryHingeStatus(rawValue: rawStatus) ?? .unknown
        return SentryHingeState(status: status, angle: angle)
    }
}

#endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK
