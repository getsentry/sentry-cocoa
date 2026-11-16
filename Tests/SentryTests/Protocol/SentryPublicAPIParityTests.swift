// Use only the public main module: importing the crash adapter would hide an API regression.
#if SWIFT_PACKAGE && !SDK_V10
import SentrySwift
#else
import Sentry
#endif
import XCTest

final class SentryPublicAPIParityTests: XCTestCase {
    func testTracesSamplerCallback_whenAssignedToOptions_shouldPreserveContextAndResult() throws {
        // -- Arrange --
        let context = SamplingContext(transactionContext: TransactionContext(name: "parity", operation: "test"))
        let expectedRate = NSNumber(value: 0.5)
        let options = Options()
        let sampler: SentryTracesSamplerCallback = { receivedContext in
            XCTAssertTrue(receivedContext === context)
            return expectedRate
        }

        // -- Act --
        options.tracesSampler = sampler
        let configuredSampler = try XCTUnwrap(options.tracesSampler)
        let result = configuredSampler(context)

        // -- Assert --
        XCTAssertEqual(result, expectedRate)
    }

    #if !SDK_V10
    func testCrashCallback_whenImportedFromMainModule_shouldExposeEntryPoint() {
        // -- Arrange --
        // -- Act --
        #if SWIFT_PACKAGE
        let callback: (() -> Void)? = SentrySwift.sentry_finishAndSaveTransaction
        #else
        let callback: (() -> Void)? = Sentry.sentry_finishAndSaveTransaction
        #endif

        // -- Assert --
        XCTAssertNotNil(callback)
    }
    #endif
}
