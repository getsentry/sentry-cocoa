import Foundation
#if SWIFT_PACKAGE
import SentryTestsSwiftHelpers
#endif

extension Bundle {
    static var sentryTestResources: Bundle {
        SentryTestResources.bundle
    }
}
