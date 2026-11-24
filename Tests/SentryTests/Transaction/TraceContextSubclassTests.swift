#if SWIFT_PACKAGE && !SDK_V10
import SentrySwift
#else
import Sentry
#endif
import XCTest

/// External subclass of the public trace context. This file imports the SDK normally, not
/// `@testable`, so a `required init()` would fail to compile here.
final class CustomTraceContext: TraceContext {
    let label: String

    init(label: String) {
        self.label = label
        super.init()
    }
}

class TraceContextSubclassTests: XCTestCase {
    func testInit_whenSubclassedOutsideTheSDK_shouldCallSuperInit() {
        // -- Arrange --
        let label = "custom"

        // -- Act --
        let context = CustomTraceContext(label: label)

        // -- Assert --
        XCTAssertEqual(context.label, label)
        XCTAssertEqual(context.publicKey, "")
        XCTAssertEqual(context.traceId, SentryId.empty)
    }
}
