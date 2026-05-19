// swiftlint:disable missing_docs
import Foundation

#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif

// See SentryReplayOptionsCompat.swift for the rationale on why this
// wrapper exists (mangled ObjC runtime names).
//
// TYPE-ERASING LIMITATION
// -----------------------
// This file uses full type-erasing: SDK types (SentryId, Attachment,
// SentryFeedback.SentryFeedbackSource) are replaced with NSObject / Int
// in every public signature.  This is a known consequence of
// internal import: types from an impl-only imported module
// CANNOT appear in a public or @usableFromInline interface.
//
// What this costs:
//   - ObjC consumers lose compile-time type safety on these parameters.
//     They pass NSObject where the underlying API expects SentryId or
//     Attachment, and pass Int raw values where the API expects an enum.
//   - Invalid types (wrong NSObject subclass, out-of-range Int) are
//     silently ignored or default-substituted at runtime instead of
//     failing at compile time.
//
// Why it's necessary:
//   Without internal import, the SentryObjCCompat module would
//   re-export Sentry's Swift types in its .swiftmodule, which defeats
//   the entire purpose of the pure-ObjC wrapper (no *-Swift.h in the
//   consumer's build graph).
//
// The alternative — adding @objc(SentryFeedback) to the original Swift
// class — eliminates this wrapper entirely and restores full type safety,
// but modifies existing SDK source files.
@objc(SentryFeedback)
public class SentryFeedbackCompat: NSObject {
    let inner: SentryFeedback

    @objc public var eventId: NSObject { inner.eventId }

    @objc public init(
        message: String,
        name: String?,
        email: String?,
        source: Int = 0,
        associatedEventId: NSObject? = nil,
        attachments: [NSObject]? = nil
    ) {
        let feedbackSource = SentryFeedback.SentryFeedbackSource(rawValue: source) ?? .widget
        self.inner = SentryFeedback(
            message: message,
            name: name,
            email: email,
            source: feedbackSource,
            associatedEventId: associatedEventId as? SentryId,
            attachments: attachments as? [Attachment]
        )
        super.init()
    }
}
