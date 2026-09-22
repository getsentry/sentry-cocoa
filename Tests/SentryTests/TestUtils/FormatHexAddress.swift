#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#endif
import Foundation

func formatHexAddress(value: UInt64) -> String {
    return String(format: "0x%016llx", value)
}
