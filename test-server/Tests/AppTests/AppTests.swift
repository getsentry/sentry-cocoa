@testable import App
import Testing
import VaporTesting

@Suite
struct AppTests {
    @Test
    func health_whenRequested_shouldReturnOK() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "health") { response in
                #expect(response.status == .ok)
                #expect(response.body.string == "OK")
            }
        }
    }

    @Test
    func root_whenRequested_shouldReturnExpectedResponse() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "") { response in
                #expect(response.status == .ok)
                #expect(response.body.string == "It works!")
            }
        }
    }

    @Test
    func echoBaggageHeader_whenHeaderIsPresent_shouldReturnHeaderValue() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "echo-baggage-header", headers: ["baggage": "sentry-trace_id=123"]) { response in
                #expect(response.status == .ok)
                #expect(response.body.string == "sentry-trace_id=123")
            }
        }
    }

    @Test
    func echoBaggageHeader_whenHeaderIsMissing_shouldReturnNoHeader() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "echo-baggage-header") { response in
                #expect(response.status == .ok)
                #expect(response.body.string == "(NO-HEADER)")
            }
        }
    }

    @Test
    func echoSentryTrace_whenHeaderIsPresent_shouldReturnHeaderValue() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "echo-sentry-trace", headers: ["sentry-trace": "123-456-1"]) { response in
                #expect(response.status == .ok)
                #expect(response.body.string == "123-456-1")
            }
        }
    }

    @Test
    func echoSentryTrace_whenHeaderIsMissing_shouldReturnNoHeader() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "echo-sentry-trace") { response in
                #expect(response.status == .ok)
                #expect(response.body.string == "(NO-HEADER)")
            }
        }
    }

    @Test
    func httpClientError_whenRequested_shouldReturnBadRequest() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "http-client-error") { response in
                #expect(response.status == .badRequest)
            }
        }
    }
}
