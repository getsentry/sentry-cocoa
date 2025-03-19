import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)

/// Test how combinations of the following options interact to ultimately decide whether or not to start the profiler on the next app launch.
/// - `enableLaunchProfiling` (v1 of launch profiling; deprecated)
/// - `enableTracing` (v1 of enabling transaction-based profiling; deprecated)
///
/// Trace sample rates (tracing v2) affect both transaction-based profiling (deprecated) and continuous profiling v2; setting `nil` for both effectively disables tracing
/// - `tracesSampleRate`
/// - `tracesSampler`
///
/// - `enableTracing` (v1 option to enable tracing; deprecated)
///
/// If both of the following profile sampling v1 options (deprecated) are set to nil, we're testing continuous profiling v1, otherwise, we're testing transaction-based profiling v2
/// - `profilesSampleRate` (set to `nil` to enable continuous profiling, which ignores sample rates)
/// - `profilesSampler` (return `nil` to enable continuous profiling, which ignores sample rates)
///
/// The following three options are for continuous profiling v2; all nil means we're testing continuous profiling v1, if any are defined, we're testing v2
/// - `SentryProfileOptions.lifecycle`
/// - `SentryProfileOptions.sessionSampleRate`
/// - `SentryProfileOptions.profileAppStarts`
final class SentryAppStartProfilingConfigurationTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
}

extension SentryAppStartProfilingConfigurationTests {
    func testShouldProfileLaunchBasedOnOptionsCombinations() {
        SentryDependencyContainer.sharedInstance().random = TestRandom(value: 1)
        for enableAppLaunchProfilingOption in [true, false] {
            LaunchProfileOptions.TracingOptions.iterateCombinations { tracesSampleRateOption, tracesSamplerReturnValueOption in
                LaunchProfileOptions.ProfileSamplingV1Options.iterateCombinations { profilesSampleRateOption, profilesSamplerReturnValueOption in
                    LaunchProfileOptions.ContinuousProfileV2Options.iterateCombinations { continuousProfileV2Options in
                        let actualOptions = Options()
                        actualOptions.enableAppLaunchProfiling = enableAppLaunchProfilingOption

                        if let tracesSampleRate = tracesSampleRateOption {
                            actualOptions.tracesSampleRate = NSNumber(value: tracesSampleRate)
                        } else {
                            actualOptions.tracesSampleRate = nil
                        }
                        if let tracesSamplerReturnValue = tracesSamplerReturnValueOption {
                            actualOptions.tracesSampler = { _ in
                                NSNumber(value: tracesSamplerReturnValue)
                            }
                        } else {
                            actualOptions.tracesSampler = nil
                        }

                        if let profilesSampleRate = profilesSampleRateOption {
                            actualOptions.profilesSampleRate = NSNumber(value: profilesSampleRate)
                        } else {
                            actualOptions.profilesSampleRate = nil
                        }
                        if let profilesSamplerReturnValue = profilesSamplerReturnValueOption {
                            actualOptions.profilesSampler = { _ in
                                NSNumber(value: profilesSamplerReturnValue)
                            }
                        } else {
                            actualOptions.profilesSampler = nil
                        }

                        if let continuousProfileV2Options = continuousProfileV2Options {
                            actualOptions.configureProfiling = {
                                $0.lifecycle = continuousProfileV2Options.lifecycle
                                $0.sessionSampleRate = continuousProfileV2Options.sessionSampleRate
                                $0.profileAppStarts = continuousProfileV2Options.profileAppStarts
                            }
                        }

                        let expectedOptions = LaunchProfileOptions(enableAppLaunchProfiling: enableAppLaunchProfilingOption, tracingOptions: .init(tracesSampleRate: tracesSampleRateOption, tracesSamplerReturnValue: tracesSamplerReturnValueOption), profileSamplingV1Options: .init(profilesSampleRate: profilesSampleRateOption, profilesSamplerReturnValue: profilesSamplerReturnValueOption), continuousProfileV2Options: continuousProfileV2Options)
                        let expectedDecision = LaunchProfileOptions.validCombinations.contains(expectedOptions)

                        // this is where SentryOptions.configureProfiling is evaluated
                        sentry_configureContinuousProfiling(actualOptions)

                        let actualDecision = sentry_willProfileNextLaunch(actualOptions)

                        XCTAssertEqual(expectedDecision, actualDecision, "Expected \(expectedDecision ? "" : "not ")to enable app launch profiling with options: LaunchProfileOptions(enableAppLaunchProfiling: \(enableAppLaunchProfilingOption), tracingOptions: .init(tracesSampleRate: \(String(describing: tracesSampleRateOption)), tracesSamplerReturnValue: \(String(describing: tracesSamplerReturnValueOption))), profileSamplingV1Options: .init(profilesSampleRate: \(String(describing: profilesSampleRateOption)), profilesSamplerReturnValue: \(String(describing: profilesSamplerReturnValueOption))), continuousProfileV2Options: \(String(describing: continuousProfileV2Options))) }")
                    }
                }
            }
        }
    }
}

struct LaunchProfileOptions: Equatable {
    let enableAppLaunchProfiling: Bool

    struct TracingOptions: Equatable {
        let tracesSampleRate: Float?
        let tracesSamplerReturnValue: Float?

        static func iterateCombinations(_ combo: (_ sampleRate: Float?, _ samplerReturnValue: Float?) -> Void) {
            for sampleRate: Float? in [nil, 0, 1] {
                for samplerReturnValue: Float? in [nil, 0, 1] {
                    combo(sampleRate, samplerReturnValue)
                }
            }
        }

        static let validCombinationsTransactionProfiling: [TracingOptions] = {
            var combos = [TracingOptions]()
            iterateCombinations { sampleRate, samplerReturnValue in
                if samplerReturnValue == 0 { return }
                if (sampleRate == nil || sampleRate == 0) && samplerReturnValue == nil { return }
                combos.append(TracingOptions(tracesSampleRate: sampleRate, tracesSamplerReturnValue: samplerReturnValue))
            }
            return combos
        }()

        static let validCombinationsContinuousProfilingV1: [TracingOptions] = {
            var combos = [TracingOptions]()
            iterateCombinations { tracesSampleRate, tracesSamplerReturnValue in
                combos.append(TracingOptions(tracesSampleRate: tracesSampleRate, tracesSamplerReturnValue: tracesSamplerReturnValue))
            }
            return combos
        }()

        static let validCombinationsContinuousProfilingV2ManualLifecycle: [TracingOptions] = validCombinationsContinuousProfilingV1

        static let validCombinationsContinuousProfilingV2TraceLifecycle: [TracingOptions] = validCombinationsTransactionProfiling
    }

    let tracingOptions: TracingOptions

    struct ProfileSamplingV1Options: Equatable {
        let profilesSampleRate: Float?
        let profilesSamplerReturnValue: Float?

        static func iterateCombinations(_ combo: (_ sampleRate: Float?, _ samplerReturnValue: Float?) -> Void) {
            for sampleRate: Float? in [nil, 0, 1] {
                for samplerReturnValue: Float? in [nil, 0, 1] {
                    combo(sampleRate, samplerReturnValue)
                }
            }
        }

        static let validCombinationsTransactionProfiling: [ProfileSamplingV1Options] = {
            var combos = [ProfileSamplingV1Options]()
            iterateCombinations { sampleRate, samplerReturnValue in
                if samplerReturnValue == 0 { return }
                if (sampleRate == nil || sampleRate == 0) && samplerReturnValue == nil { return }
                combos.append(ProfileSamplingV1Options(profilesSampleRate: sampleRate, profilesSamplerReturnValue: samplerReturnValue))
            }
            return combos
        }()

        static let validCombinationsContinuousProfilingV1: [ProfileSamplingV1Options] = {
            [ProfileSamplingV1Options(profilesSampleRate: nil, profilesSamplerReturnValue: nil)]
        }()

        static let validCombinationsContinuousProfilingV2ManualLifecycle: [ProfileSamplingV1Options] = validCombinationsContinuousProfilingV1

        static let validCombinationsContinuousProfilingV2TraceLifecycle: [ProfileSamplingV1Options] = validCombinationsContinuousProfilingV1
    }

    let profileSamplingV1Options: ProfileSamplingV1Options

    struct ContinuousProfileV2Options: Equatable, CustomStringConvertible {
        let lifecycle: SentryProfileOptions.SentryProfileLifecycle
        let sessionSampleRate: Float
        let profileAppStarts: Bool

        static func iterateCombinations(_ combo: (ContinuousProfileV2Options?) -> Void) {
            combo(nil)
            for lifecycle: SentryProfileOptions.SentryProfileLifecycle in [.manual, .trace] {
                for sampleRate: Float in [0, 1] {
                    for profileAppStarts in [true, false] {
                        combo(ContinuousProfileV2Options(lifecycle: lifecycle, sessionSampleRate: sampleRate, profileAppStarts: profileAppStarts))
                    }
                }
            }
        }

        static let validCombinationsTransactionProfiling: [ContinuousProfileV2Options?] = {
            var combos = [ContinuousProfileV2Options?]()
            iterateCombinations { combo in
                combos.append(combo)
            }
            return combos
        }()

        static let validCombinationsContinuousProfilingV1: [ContinuousProfileV2Options?] = {
            var combos = [ContinuousProfileV2Options?]()
            iterateCombinations { combo in
                combos.append(combo)
            }
            return combos
        }()

        static let validCombinationsManualLifecycle: [ContinuousProfileV2Options] = {
            var combos = [ContinuousProfileV2Options]()
            iterateCombinations { combo in
                guard let combo = combo, combo.lifecycle == .manual, combo.profileAppStarts, combo.sessionSampleRate == 1 else { return }
                combos.append(combo)
            }
            return combos
        }()

        static let validCombinationsTraceLifecycle: [ContinuousProfileV2Options] = {
            var combos = [ContinuousProfileV2Options]()
            iterateCombinations { combo in
                guard let combo = combo, combo.lifecycle == .trace, combo.profileAppStarts, combo.sessionSampleRate == 1 else { return }
                combos.append(combo)
            }
            return combos
        }()

        var description: String {
            switch lifecycle {
            case .manual:
                return "lifecycle: manual, sessionSampleRate: \(sessionSampleRate), profileAppStarts: \(profileAppStarts)"
            case .trace:
                return "lifecycle: trace, sessionSampleRate: \(sessionSampleRate), profileAppStarts: \(profileAppStarts)"
            @unknown default:
                return "unknown lifecycle, sessionSampleRate: \(sessionSampleRate), profileAppStarts: \(profileAppStarts)"
            }
        }
    }

    let continuousProfileV2Options: ContinuousProfileV2Options?

    static let validCombinations: [LaunchProfileOptions] = {
        var combos = [LaunchProfileOptions]()
        for tracingOptions in TracingOptions.validCombinationsTransactionProfiling {
            for profileSamplingV1Options in ProfileSamplingV1Options.validCombinationsTransactionProfiling {
                for continuousProfileV2Options in ContinuousProfileV2Options.validCombinationsTransactionProfiling {
                    combos.append(.init(enableAppLaunchProfiling: true, tracingOptions: tracingOptions, profileSamplingV1Options: profileSamplingV1Options, continuousProfileV2Options: continuousProfileV2Options))
                }
            }
        }
        for tracingOptions in TracingOptions.validCombinationsContinuousProfilingV1 {
            for profileSamplingV1Options in ProfileSamplingV1Options.validCombinationsContinuousProfilingV1 {
                for continuousProfileV2Options in ContinuousProfileV2Options.validCombinationsContinuousProfilingV1 {
                    combos.append(.init(enableAppLaunchProfiling: true, tracingOptions: tracingOptions, profileSamplingV1Options: profileSamplingV1Options, continuousProfileV2Options: continuousProfileV2Options))
                }
            }
        }
        for enableAppLaunchProfilingOption in [true, false] {
            for tracingOptions in TracingOptions.validCombinationsContinuousProfilingV2TraceLifecycle {
                for profileSamplingV1Options in ProfileSamplingV1Options.validCombinationsContinuousProfilingV2TraceLifecycle {
                    for continuousProfilingV2Options in ContinuousProfileV2Options.validCombinationsTraceLifecycle {
                        combos.append(.init(enableAppLaunchProfiling: enableAppLaunchProfilingOption, tracingOptions: tracingOptions, profileSamplingV1Options: profileSamplingV1Options, continuousProfileV2Options: continuousProfilingV2Options))
                    }
                }}
            for tracingOptions in TracingOptions.validCombinationsContinuousProfilingV2ManualLifecycle {
                for profileSamplingV1Options in ProfileSamplingV1Options.validCombinationsContinuousProfilingV2ManualLifecycle {
                    for continuousProfilingV2Options in ContinuousProfileV2Options.validCombinationsManualLifecycle {
                        combos.append(.init(enableAppLaunchProfiling: enableAppLaunchProfilingOption, tracingOptions: tracingOptions, profileSamplingV1Options: profileSamplingV1Options, continuousProfileV2Options: continuousProfilingV2Options))
                    }
                }
            }
        }
        return combos
    }()
}

#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
