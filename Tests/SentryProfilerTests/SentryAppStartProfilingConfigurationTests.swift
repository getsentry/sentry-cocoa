import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)

/// Test how combinations of the following options interact to ultimately decide whether or not to start the profiler on the next app launch.
/// - `enableLaunchProfiling` (v1 of launch profiling; deprecated)
///
/// Trace sample rates (tracing v2) affect both transaction-based profiling (deprecated) and continuous profiling v2
/// - `tracesSampleRate`
///
/// If profile sampling rate (deprecated) is set to nil, we're testing continuous profiling v1 if the v2 options aren't configured, or v2 if they are
/// - `profilesSampleRate`
///
/// The following three options are for continuous profiling v2; all nil means we're testing continuous profiling v1, if any are defined, we're testing v2
/// - `SentryProfileOptions.lifecycle`
/// - `SentryProfileOptions.sessionSampleRate`
/// - `SentryProfileOptions.profileAppStarts`
final class SentryAppStartProfilingConfigurationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        SentryDependencyContainer.sharedInstance().random = TestRandom(value: 1)
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
}

extension SentryAppStartProfilingConfigurationTests {
    func testValidCombinations() {
        for config in SentryAppStartProfilingConfigurationTests.validConfigurations {
            performTest(expectedOptions: config, shouldProfileLaunch: true)
        }
    }

    func testInvalidTransactionProfilingConfigurations() {
        for config in SentryAppStartProfilingConfigurationTests.invalidTransactionProfilingConfigurations {
            performTest(expectedOptions: config, shouldProfileLaunch: false)
        }
    }

    func testInvalidContinuousProfilingV1Configurations() {
        for config in SentryAppStartProfilingConfigurationTests.invalidContinuousProfilingV1Configurations {
            performTest(expectedOptions: config, shouldProfileLaunch: false)
        }
    }

    func testInvalidTransactionProfilingWithV2OptionsConfigurations() {
        for config in SentryAppStartProfilingConfigurationTests.invalidTransactionProfilingWithV2OptionsConfigurations {
            performTest(expectedOptions: config, shouldProfileLaunch: false)
        }
    }

    func testInvalidContinuousProfilingV2Configurations() {
        for config in SentryAppStartProfilingConfigurationTests.invalidContinuousProfilingV2Configurations {
            performTest(expectedOptions: config, shouldProfileLaunch: false)
        }
    }
}

private extension SentryAppStartProfilingConfigurationTests {
    private func performTest(expectedOptions: LaunchProfileOptions, shouldProfileLaunch: Bool) {
        let actualOptions = Options()
        actualOptions.enableAppLaunchProfiling = expectedOptions.enableAppLaunchProfiling

        if let tracesSampleRate = expectedOptions.tracesSampleRate {
            actualOptions.tracesSampleRate = NSNumber(value: tracesSampleRate)
        } else {
            actualOptions.tracesSampleRate = nil
        }

        if let profilesSampleRate = expectedOptions.profilesSampleRate {
            actualOptions.profilesSampleRate = NSNumber(value: profilesSampleRate)
        } else {
            actualOptions.profilesSampleRate = nil
        }

        if let continuousProfileV2Options = expectedOptions.continuousProfileV2Options {
            actualOptions.configureProfiling = {
                $0.lifecycle = continuousProfileV2Options.lifecycle
                $0.sessionSampleRate = continuousProfileV2Options.sessionSampleRate
                $0.profileAppStarts = continuousProfileV2Options.profileAppStarts
            }
        }

        // this is where SentryOptions.configureProfiling is evaluated
        sentry_configureContinuousProfiling(actualOptions)

        let actualIsValid = sentry_willProfileNextLaunch(actualOptions)
        if shouldProfileLaunch {
            XCTAssert(actualIsValid, "Expected to enable app launch profiling with options:\n\(expectedOptions.description)")
        } else {
            XCTAssertFalse(actualIsValid, "Expected to disable app launch profiling with options:\n\(expectedOptions.description)")
        }
    }
}

// MARK: -
// MARK: Configuration combination lists
// MARK: -
private extension SentryAppStartProfilingConfigurationTests {
    static let invalidTransactionProfilingConfigurations = [
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: 0),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: 1),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: nil, profilesSampleRate: 0),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: nil, profilesSampleRate: 1),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: nil, profilesSampleRate: 0)
    ]

    static let invalidContinuousProfilingV1Configurations = [
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: nil),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: nil),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: nil)
    ]

    static let invalidTransactionProfilingWithV2OptionsConfigurations = [
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: true)),

        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: true)),

        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: true)),

        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: true)),

        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: true)),

        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: true)),

        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: true)),

        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: true)),

        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: true))
    ]

    static let invalidContinuousProfilingV2Configurations = [
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: false)),

        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: true)),

        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: true)),

        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: nil, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: nil, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: nil, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: nil, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: nil, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: nil, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: nil, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: true)),

        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 1, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 1, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 1, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 1, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 1, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 1, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: false)),

        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: true))
    ]

    static let validConfigurations = [
        // the only transaction profiling configuration that will profile a launch
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 1, profilesSampleRate: 1),

        // continuous profiling v1 configurations
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: nil),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 1, profilesSampleRate: nil),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: nil, profilesSampleRate: nil),

        //
        // configurations with continuous profiling v2 options set that are not short circuited to either transaction profiling or continuous v1
        //

        // continuous profiling v2 trace lifecycle configurations
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 1, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: true)),

        // continuous profiling v2 manual lifecycle configurations
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 0, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: 1, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: false, tracesSampleRate: nil, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 0, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: 1, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true)),
        LaunchProfileOptions(enableAppLaunchProfiling: true, tracesSampleRate: nil, profilesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true))
    ]
}

// MARK: -
// MARK: Data structures
// MARK: -
struct LaunchProfileOptions: Equatable {
    /// transaction profiling and continuous profiling v1
    let enableAppLaunchProfiling: Bool

    /// to test transaction based profiling and continuous v2 trace lifecycle
    let tracesSampleRate: Float?

    /// nonnil to test transaction profiling, nil to test continuous v1 and v2
    let profilesSampleRate: Float?

    struct ContinuousProfileV2Options: Equatable {
        let lifecycle: SentryProfileOptions.SentryProfileLifecycle
        let sessionSampleRate: Float
        let profileAppStarts: Bool
    }

    ///
    var continuousProfileV2Options: ContinuousProfileV2Options?
}

// MARK: -
// MARK: Debug logging
// MARK: -
extension LaunchProfileOptions: CustomStringConvertible {
    var description: String {
        return "LaunchProfileOptions(\n"
        + "\tenableAppLaunchProfiling: \(enableAppLaunchProfiling),\n"
        + "\ttracesSampleRate: \(String(describing: tracesSampleRate)),\n"
        + "\tprofilesSampleRate: \(String(describing: profilesSampleRate)),\n"
        + "\tcontinuousProfileV2Options: \(String(describing: continuousProfileV2Options))\n"
        + ")"
    }
}

extension SentryProfileOptions.SentryProfileLifecycle: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .manual:
            return "manual"
        case .trace:
            return "trace"
        @unknown default:
            return "unknown"
        }
    }
}

extension LaunchProfileOptions.ContinuousProfileV2Options: CustomStringConvertible {
    var description: String {
        return "ContinuousProfileV2Options(\n"
        + "\t\tlifecycle: \(lifecycle.description),\n"
        + "\t\tsessionSampleRate: \(sessionSampleRate),\n"
        + "\t\tprofileAppStarts: \(profileAppStarts)\n"
        + "\t)"
    }
}

#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
