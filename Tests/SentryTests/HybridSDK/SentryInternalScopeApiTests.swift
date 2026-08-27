@_spi(Private) @testable import Sentry
import XCTest

final class SentryInternalScopeApiTests: XCTestCase {

    func testSerializedContexts_whenScopeContainsContext_shouldReturnContextAndTrace() throws {
        // -- Arrange --
        let scope = Scope()
        scope.setContext(value: ["value": "test"], key: "hybrid")
        let sut = SentryInternalScopeApi(dependencies: Dependencies(scope: scope))

        // -- Act --
        let contexts = sut.serializedContexts()

        // -- Assert --
        let hybrid = try XCTUnwrap(contexts["hybrid"])
        XCTAssertEqual(hybrid["value"] as? String, "test")
        XCTAssertNotNil(contexts["trace"])
    }

    private struct Dependencies: HubProvider {
        let hub: Hub

        init(scope: Scope) {
            hub = TestHub(scope: scope)
        }
    }

    private final class TestHub: Hub {
        let scope: Scope

        init(scope: Scope) {
            self.scope = scope
        }

        func configureScope(_ callback: @escaping (Scope) -> Void) {
            callback(scope)
        }

        func storeEnvelope(_ envelope: SentryEnvelope) {}

        func captureEnvelope(_ envelope: SentryEnvelope) {}

        func captureErrorEvent(event: Event) {}

        func setTrace(_ traceId: SentryId, spanId: SpanId) {}

        func withCurrentScope(_ scope: Scope, callback: () -> Void) { callback() }

        var currentOptions: Options? { nil }

        var options: Options { Options() }
    }
}
