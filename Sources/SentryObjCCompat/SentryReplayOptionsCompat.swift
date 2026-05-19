// swiftlint:disable missing_docs
import Foundation

#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif

// Provides the stable ObjC runtime name _OBJC_CLASS_$_SentryReplayOptions.
//
// The real SentryReplayOptions class (in the SDK) uses @objcMembers without
// a class-level @objc(Name), so its ObjC runtime name is mangled
// (e.g. _TtC11SentrySwift20SentryReplayOptions).  The hand-written ObjC
// header SentryObjC/Public/SentryReplayOptions.h declares
// @interface SentryReplayOptions : NSObject, which resolves to the plain
// symbol.  This wrapper claims that symbol.
//
// LIMITATION 1 — ObjC CATEGORIES:
// ObjC categories declared on SentryReplayOptions (like the one in
// SentryReplayOptionsObjCBridge.m) bind to THIS class, not the real Swift
// class.  Since options.sessionReplay returns the real Swift object, category
// methods are not available on those instances at runtime.  A full solution
// requires either @objc(SentryReplayOptions) on the original Swift class or
// returning wrapper instances from the compat bridge.
//
// LIMITATION 2 — TYPE-ERASING:
// The `quality` property uses Int (raw value) instead of the SDK's
// SentryReplayQuality enum.  This is a known consequence of
// internal import: types from an impl-only imported module
// CANNOT appear in a public or @usableFromInline interface.
//
// What this costs:
//   - ObjC consumers pass an Int where the underlying API expects
//     SentryReplayQuality.  Invalid raw values (outside 0..2) are not
//     caught at compile time.
//
// Why it's necessary:
//   Without internal import, the SentryObjCCompat module would
//   re-export Sentry's Swift types in its .swiftmodule, which defeats
//   the entire purpose of the pure-ObjC wrapper (no *-Swift.h in the
//   consumer's build graph).
//
// The alternative — adding @objc(SentryReplayOptions) to the original
// Swift class — eliminates this wrapper entirely and restores full type
// safety, but modifies existing SDK source files.
#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))
@objc(SentryReplayOptions)
public class SentryReplayOptionsCompat: NSObject {
    @objc public var sessionSampleRate: Float = SentryReplayOptions.DefaultValues.sessionSampleRate
    @objc public var onErrorSampleRate: Float = SentryReplayOptions.DefaultValues.onErrorSampleRate
    @objc public var maskAllText: Bool = SentryReplayOptions.DefaultValues.maskAllText
    @objc public var maskAllImages: Bool = SentryReplayOptions.DefaultValues.maskAllImages
    @objc public var quality: Int = SentryReplayOptions.DefaultValues.quality.rawValue
    @objc public var enableViewRendererV2: Bool = SentryReplayOptions.DefaultValues.enableViewRendererV2
    @objc public var enableFastViewRendering: Bool = SentryReplayOptions.DefaultValues.enableFastViewRendering
    @objc public var networkCaptureBodies: Bool = false
}
#endif
