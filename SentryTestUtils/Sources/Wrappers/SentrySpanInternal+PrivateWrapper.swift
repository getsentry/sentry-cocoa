#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import _SentryPrivate
import Foundation
import SentryTestUtilsObjC
import XCTest

#if SWIFT_PACKAGE && (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
extension SentrySpanInternal {
    @_spi(Private) @nonobjc public convenience init(context: SpanContext, framesTracker: SentryFramesTracker?) {
        self.init(testContext: context, testFramesTracker: framesTracker)
    }
}
#endif
