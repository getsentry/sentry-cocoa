import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
final class SentryAppLaunchProfilingSwiftTests: XCTestCase {
    func testContentsOfLegacyLaunchProfileTransactionContext() {
        let context = sentry_context(NSNumber(value: 1))
        XCTAssertEqual(context.nameSource.rawValue, 0)
        XCTAssertEqual(context.origin, "auto.app.start.profile")
        XCTAssertEqual(context.sampled, .yes)
    }
    
    /**
     * Test how combinations of the following options interact to ultimately decide whether or not to start the profiler on the next app launch..
     * - `enableLaunchProfiling`
     * - `enableTracing`
     * - `enableContinuousProfiling` (always profiles regardless of sample rate or trace options)
     * - `tracesSampleRate`
     * - `profilesSampleRate`
     * - `profilesSampler`
     */
    func testShouldProfileLaunchBasedOnOptionsCombinations() {
        for testCase: (enableAppLaunchProfiling: Bool, enableTracing: Bool, enableContinuousProfiling: Bool, tracesSampleRate: Int, profilesSampleRate: Int, profilesSamplerReturnValue: Int, shouldProfileLaunch: Bool) in [
            // everything false/0
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            // change profilesSampleRate to 1
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            // change tracesSampleRate to 1
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            // change enableContinuousProfiling to true
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            // change enableTracing to true
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            // change enableAppLaunchProfiling to true
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            // change profilesSamplerReturnValue to 1
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: true)
        ] {
            let options = Options()
            options.enableAppLaunchProfiling = testCase.enableAppLaunchProfiling
            options.enableTracing = testCase.enableTracing
            options.enableContinuousProfiling = testCase.enableContinuousProfiling
            options.tracesSampleRate = NSNumber(value: testCase.tracesSampleRate)
            options.profilesSampleRate = NSNumber(value: testCase.profilesSampleRate)
            options.profilesSampler = { _ in
                NSNumber(value: testCase.profilesSamplerReturnValue)
            }
            XCTAssertEqual(sentry_willProfileNextLaunch(options), testCase.shouldProfileLaunch, "Expected \(testCase.shouldProfileLaunch ? "" : "not ")to enable app launch profiling with options: { enableAppLaunchProfiling: \(testCase.enableAppLaunchProfiling), enableTracing: \(testCase.enableTracing), enableContinuousProfiling: \(testCase.enableContinuousProfiling), tracesSampleRate: \(testCase.tracesSampleRate), profilesSampleRate: \(testCase.profilesSampleRate), profilesSamplerReturnValue: \(testCase.profilesSamplerReturnValue) }")
        }
    }
}
#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
