// swiftlint:disable missing_docs
import Foundation

#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif

// See SentryReplayOptionsCompat.swift for the rationale on why this
// wrapper exists (mangled ObjC runtime names).
//
// This wrapper avoids type-erasing because SentryAttribute's public
// interface already uses only primitive types (String, Bool, Int, Double)
// and `Any` for the value getter.  No SDK types leak into public
// signatures.
@objc(SentryAttribute)
public class SentryAttributeCompat: NSObject {
    let inner: SentryAttribute

    @objc public var type: String { inner.type }
    @objc public var value: Any { inner.value }

    @objc public init(string value: String) {
        self.inner = SentryAttribute(string: value)
        super.init()
    }

    @objc public init(boolean value: Bool) {
        self.inner = SentryAttribute(boolean: value)
        super.init()
    }

    @objc public init(integer value: Int) {
        self.inner = SentryAttribute(integer: value)
        super.init()
    }

    @objc public init(double value: Double) {
        self.inner = SentryAttribute(double: value)
        super.init()
    }
}
