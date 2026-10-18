import SentrySampleShared
import XCTest

class LaunchProfilingVCTransactionUITests: BaseUITest {
    override var automaticallyLaunchAndTerminateApp: Bool { false }

    func testVCTransactionsCapturedDuringLaunchProfiling() throws {
        guard #available(iOS 16, *) else {
            throw XCTSkip("Launch profiling requires iOS 16+")
        }

        // -- First launch: configure profiling for next launch --
        launchApp(args: [
            SentrySDKOverrides.Special.wipeDataOnLaunch.rawValue
        ], env: [
            SentrySDKOverrides.Profiling.sessionSampleRate.rawValue: "1"
        ])
        app.terminate()

        // -- Second launch: profiling active with VC tracing enabled --
        // ErrorsViewController loads automatically (first tab).
        // Navigate to Extra tab so ExtraViewController also loads and finishes its transaction.
        app = newAppSession()
        app.launchEnvironment[SentrySDKOverrides.Profiling.sessionSampleRate.rawValue] = "1"
        launchApp()

        app.tabBars["Tab Bar"].buttons["Extra"]
            .afterWaitingForExistence("Couldn't find Extra tab")
            .tap()

        app.buttons["io.sentry.ui-tests.check-launch-vc-transactions"]
            .afterWaitingForExistence("Couldn't find launch VC transaction check button")
            .tap()

        let capturedData = try readMarshaledData()
        let spans = try parseSpanArray(capturedData)

        // First VC span is discarded
        let errorsVCLoad = spans.first {
            $0["operation"] == "ui.load.initial_display" && $0["description"]?.contains("ErrorsViewController") == true
        }
        XCTAssertNil(errorsVCLoad, "ErrorsViewController ui.load.initial_display span must be not captured during launch profiling. Captured spans: \(spans)")

        // Later VC spans should be available
        let extraVCLoad = spans.first {
            $0["operation"] == "ui.load.initial_display" && $0["description"]?.contains("ExtraViewController") == true
        }
        XCTAssertNotNil(extraVCLoad, "ExtraViewController ui.load.initial_display span must be captured after navigating during launch profiling. Captured spans: \(spans)")
    }
}

// MARK: - Helpers

private extension LaunchProfilingVCTransactionUITests {
    func readMarshaledData() throws -> String {
        let field = app.textFields["io.sentry.ui-test.text-field.data-marshaling.extras"]
            .afterWaitingForExistence("Couldn't find data marshaling text field.")
        return try XCTUnwrap(field.value as? String)
    }

    func parseSpanArray(_ json: String) throws -> [[String: String]] {
        XCTAssertNotEqual(json, "<empty>", "No spans captured — VC transactions may be lost during launch profiling")
        XCTAssertNotEqual(json, "<error>", "Error serializing captured spans")

        let data = try XCTUnwrap(json.data(using: .utf8))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: String]])
    }
}
