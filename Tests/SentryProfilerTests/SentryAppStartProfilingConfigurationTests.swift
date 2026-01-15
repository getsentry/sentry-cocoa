// swiftlint:disable missing_docs
@_spi(Private) import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)

/// Trace sample rates (tracing v2) affects continuous profiling v2
/// - `tracesSampleRate`
///
/// The following three options are for continuous profiling v2; if any are defined, we're testing v2
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

    func testInvalidContinuousProfilingV2Configurations() {
        for config in SentryAppStartProfilingConfigurationTests.invalidContinuousProfilingV2Configurations {
            performTest(expectedOptions: config, shouldProfileLaunch: false)
        }
    }
}

private extension SentryAppStartProfilingConfigurationTests {
    private func performTest(expectedOptions: LaunchProfileOptions, shouldProfileLaunch: Bool) {
        let actualOptions = Options()

        actualOptions.tracesSampleRate = expectedOptions.tracesSampleRate.map { NSNumber(value: $0) }
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
            XCTAssertFalse(actualIsValid, "Expected to disable app launch profiling with options:\(expectedOptions.description)")
        }
    }
}

// MARK: -
// MARK: Configuration combination lists
// MARK: -
private extension SentryAppStartProfilingConfigurationTests {
    static let invalidContinuousProfilingV2Configurations = [
        LaunchProfileOptions(tracesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(tracesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(tracesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(tracesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(tracesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(tracesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: false)),

        LaunchProfileOptions(tracesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(tracesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(tracesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(tracesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(tracesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(tracesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(tracesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: true)),

        LaunchProfileOptions(tracesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(tracesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(tracesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(tracesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: false)),
        LaunchProfileOptions(tracesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 0, profileAppStarts: true)),
        LaunchProfileOptions(tracesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: false)),
        LaunchProfileOptions(tracesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: true))
    ]

    static let validConfigurations = [
        // continuous profiling v2 trace lifecycle configurations
        LaunchProfileOptions(tracesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: true)),

        // continuous profiling v2 manual lifecycle configurations
        LaunchProfileOptions(tracesSampleRate: 0, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true)),
        LaunchProfileOptions(tracesSampleRate: 1, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true)),
        LaunchProfileOptions(tracesSampleRate: nil, continuousProfileV2Options: .init(lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true))
    ]
}

// MARK: -
// MARK: Data structures
// MARK: -
struct LaunchProfileOptions: Equatable {

    /// to test transaction based profiling and continuous v2 trace lifecycle
    let tracesSampleRate: Float?

    struct ContinuousProfileV2Options: Equatable {
        let lifecycle: SentryProfileOptions.SentryProfileLifecycle
        let sessionSampleRate: Float
        let profileAppStarts: Bool
    }

    var continuousProfileV2Options: ContinuousProfileV2Options?
}

// MARK: -
// MARK: Debug logging
// MARK: -
extension LaunchProfileOptions: CustomStringConvertible {
    var description: String {
        return "LaunchProfileOptions(\n"
        + "\ttracesSampleRate: \(String(describing: tracesSampleRate)),\n"
        + "\tcontinuousProfileV2Options: \(String(describing: continuousProfileV2Options))\n"
        + ")"
    }
}

extension SentryProfileOptions.SentryProfileLifecycle {
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
// swiftlint:enable missing_docs
