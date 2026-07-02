@_spi(Private) @testable import Sentry
import XCTest

final class SentrySDKThreadTests: XCTestCase {

    /// Stress-tests concurrent bindClient + capture. Skipped on watchOS: limited concurrency (few threads)
    /// means the 100 async blocks often don’t all run within the 10s timeout.
    func testRaceWhenBindingClient() throws {
#if !os(watchOS)

        let options = Options()
        let sut = SentryHubInternal(client: SentryClientInternal(options: options), andScope: nil)

        for _ in 0..<100 {

            let exp = expectation(description: "wait")
            exp.expectedFulfillmentCount = 100

            let queue = DispatchQueue(label: "com.sentry.test_client", qos: .userInteractive, attributes: [.concurrent, .initiallyInactive])

            for _ in 0..<100 {
                queue.async {
                    sut.bindClient(SentryClientInternal(options: options))
                    sut.capture(message: "Test message")
                    exp.fulfill()
                }
            }

            queue.activate()

            for _ in 0..<100 {
                sut.bindClient(nil)
            }

            wait(for: [exp], timeout: 10.0)
        }
#else
        throw XCTSkip("watchOS has limited concurrency; this stress test times out waiting for 100 blocks")
#endif
    }

    /// Regression test for #8267: `addBreadcrumb` calls `isEnabled`, which read the static current hub
    /// while `close()`/`setCurrentHub:` nils it and drops the last strong reference, causing a
    /// use-after-free (EXC_BAD_ACCESS).
    /// You may have to run this test repeatedly to reliably reproduce the problem.
    func testCallingIsEnabledWhileSettingHubNil_DoesNotCrash() throws {
        let options = Options()

        for _ in 0..<100 {

            // Install a hub whose only strong reference is the static currentHub, so nil'ing it
            // deallocates the hub - the exact condition that triggers the use-after-free.
            SentrySDKInternal.setCurrentHub(SentryHubInternal(client: SentryClientInternal(options: options), andScope: nil))

            let exp = expectation(description: "wait")
            exp.expectedFulfillmentCount = 200

            let queue = DispatchQueue(label: "com.sentry.test_is_enabled", qos: .userInteractive, attributes: [.concurrent, .initiallyInactive])

            for _ in 0..<100 {
                queue.async {
                    SentrySDKInternal.addBreadcrumb(Breadcrumb(level: .info, category: "test"))
                    exp.fulfill()
                }

                queue.async {
                    SentrySDKInternal.setCurrentHub(nil)
                    exp.fulfill()
                }
            }

            queue.activate()

            wait(for: [exp], timeout: 10.0)
        }

        SentrySDKInternal.setCurrentHub(nil)
    }
}
