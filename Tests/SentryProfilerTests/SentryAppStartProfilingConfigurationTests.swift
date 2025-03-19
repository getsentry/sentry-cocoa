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

//let shouldProfileLegalCombinations: [LaunchProfileOptions] = [
//    // transaction-based profiling
//    LaunchProfileOptions(enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: nil, tracesSamplerReturnValue: nil, profilesSampleRate: 0, profilesSamplerReturnValue: 1, lifecycle: nil, sessionSampleRate: nil, profileAppStarts: nil),
//    LaunchProfileOptions(enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: nil, tracesSamplerReturnValue: nil, profilesSampleRate: 1, profilesSamplerReturnValue: 1, lifecycle: nil, sessionSampleRate: nil, profileAppStarts: nil),
//    LaunchProfileOptions(enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: nil, tracesSamplerReturnValue: nil, profilesSampleRate: nil, profilesSamplerReturnValue: 1, lifecycle: nil, sessionSampleRate: nil, profileAppStarts: nil),
//    LaunchProfileOptions(enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 1, tracesSamplerReturnValue: nil, profilesSampleRate: 0, profilesSamplerReturnValue: 1, lifecycle: nil, sessionSampleRate: nil, profileAppStarts: nil),
//    LaunchProfileOptions(enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 1, tracesSamplerReturnValue: nil, profilesSampleRate: 1, profilesSamplerReturnValue: 1, lifecycle: nil, sessionSampleRate: nil, profileAppStarts: nil),
//    LaunchProfileOptions(enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 1, tracesSamplerReturnValue: nil, profilesSampleRate: nil, profilesSamplerReturnValue: 1, lifecycle: nil, sessionSampleRate: nil, profileAppStarts: nil),
//
//    // continuous profiling v1
//    LaunchProfileOptions(enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 0, tracesSamplerReturnValue: nil, profilesSampleRate: nil, profilesSamplerReturnValue: nil, lifecycle: nil, sessionSampleRate: nil, profileAppStarts: nil),
//    LaunchProfileOptions(enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 1, tracesSamplerReturnValue: nil, profilesSampleRate: nil, profilesSamplerReturnValue: nil, lifecycle: nil, sessionSampleRate: nil, profileAppStarts: nil),
//    LaunchProfileOptions(enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: 0, tracesSamplerReturnValue: nil, profilesSampleRate: nil, profilesSamplerReturnValue: nil, lifecycle: nil, sessionSampleRate: nil, profileAppStarts: nil),
//    LaunchProfileOptions(enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: 1, tracesSamplerReturnValue: nil, profilesSampleRate: nil, profilesSamplerReturnValue: nil, lifecycle: nil, sessionSampleRate: nil, profileAppStarts: nil),
//    LaunchProfileOptions(enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 0, tracesSamplerReturnValue: nil, profilesSampleRate: nil, profilesSamplerReturnValue: nil, lifecycle: nil, sessionSampleRate: nil, profileAppStarts: nil),
//    LaunchProfileOptions(enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 1, tracesSamplerReturnValue: nil, profilesSampleRate: nil, profilesSamplerReturnValue: nil, lifecycle: nil, sessionSampleRate: nil, profileAppStarts: nil),
//    LaunchProfileOptions(enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: 0, tracesSamplerReturnValue: nil, profilesSampleRate: nil, profilesSamplerReturnValue: nil, lifecycle: nil, sessionSampleRate: nil, profileAppStarts: nil),
//    LaunchProfileOptions(enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: 1, tracesSamplerReturnValue: nil, profilesSampleRate: nil, profilesSamplerReturnValue: nil, lifecycle: nil, sessionSampleRate: nil, profileAppStarts: nil),
//
//    // continuous profiling v2
//    LaunchProfileOptions(enableAppLaunchProfiling: false, enableTracing: false, tracesSampleRate: 0, tracesSamplerReturnValue: nil, profilesSampleRate: nil, profilesSamplerReturnValue: nil, lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true),
//    LaunchProfileOptions(enableAppLaunchProfiling: false, enableTracing: false, tracesSampleRate: 1, tracesSamplerReturnValue: nil, profilesSampleRate: nil, profilesSamplerReturnValue: nil, lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true),
//    LaunchProfileOptions(enableAppLaunchProfiling: false, enableTracing: true, tracesSampleRate: 0, tracesSamplerReturnValue: nil, profilesSampleRate: nil, profilesSamplerReturnValue: nil, lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true),
//    LaunchProfileOptions(enableAppLaunchProfiling: false, enableTracing: true, tracesSampleRate: 1, tracesSamplerReturnValue: nil, profilesSampleRate: nil, profilesSamplerReturnValue: nil, lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true),
//    LaunchProfileOptions(enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 0, tracesSamplerReturnValue: nil, profilesSampleRate: nil, profilesSamplerReturnValue: nil, lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true),
//    LaunchProfileOptions(enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 1, tracesSamplerReturnValue: nil, profilesSampleRate: nil, profilesSamplerReturnValue: nil, lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true),
//    LaunchProfileOptions(enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: 0, tracesSamplerReturnValue: nil, profilesSampleRate: nil, profilesSamplerReturnValue: nil, lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true),
//    LaunchProfileOptions(enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: 1, tracesSamplerReturnValue: nil, profilesSampleRate: nil, profilesSamplerReturnValue: nil, lifecycle: .manual, sessionSampleRate: 1, profileAppStarts: true),
//
//    LaunchProfileOptions(enableAppLaunchProfiling: false, enableTracing: false, tracesSampleRate: 1, tracesSamplerReturnValue: nil, profilesSampleRate: nil, profilesSamplerReturnValue: nil, lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: true),
//    LaunchProfileOptions(enableAppLaunchProfiling: false, enableTracing: true, tracesSampleRate: 0, tracesSamplerReturnValue: nil, profilesSampleRate: nil, profilesSamplerReturnValue: nil, lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: true),
//    LaunchProfileOptions(enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 1, tracesSamplerReturnValue: nil, profilesSampleRate: nil, profilesSamplerReturnValue: nil, lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: true),
//    LaunchProfileOptions(enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: 0, tracesSamplerReturnValue: nil, profilesSampleRate: nil, profilesSamplerReturnValue: nil, lifecycle: .trace, sessionSampleRate: 1, profileAppStarts: true),
//]

extension SentryAppStartProfilingConfigurationTests {
    func testShouldProfileLaunchBasedOnOptionsCombinations() {
        for enableAppLaunchProfilingOption in [true, false] {
            for enableProfilingOption in [true, false] {
                LaunchProfileOptions.TracingOptions.iterateCombinations { enableTracingOption, tracesSampleRateOption, tracesSamplerReturnValueOption in
                    LaunchProfileOptions.ProfileSamplingV1Options.iterateCombinations { profilesSampleRateOption, profilesSamplerReturnValueOption in
                        LaunchProfileOptions.ContinuousProfileV2Options.iterateCombinations { continuousProfileV2Options in
                            let options = Options()
                            options.enableAppLaunchProfiling = enableAppLaunchProfilingOption

                            // these use Dynamic(options) to work around the deprecation annotations on these property causing build errors
                            Dynamic(options).enableTracing = enableTracingOption
                            Dynamic(options).enableProfiling = enableProfilingOption

                            if let tracesSampleRate = tracesSampleRateOption {
                                options.tracesSampleRate = NSNumber(value: tracesSampleRate)
                            }
                            if let profilesSampleRate = profilesSampleRateOption {
                                options.profilesSampleRate = NSNumber(value: profilesSampleRate)
                            } else {
                                options.profilesSampleRate = nil
                            }
                            if let profilesSamplerReturnValue = profilesSamplerReturnValueOption {
                                options.profilesSampler = { _ in
                                    NSNumber(value: profilesSamplerReturnValue)
                                }
                            } else {
                                options.profilesSampler = nil
                            }

                            let actualDecision = sentry_willProfileNextLaunch(options)

                            let actualOptions = LaunchProfileOptions(enableAppLaunchProfiling: enableAppLaunchProfilingOption, enableProfiling: enableProfilingOption, tracingOptions: .init(enableTracing: enableTracingOption, tracesSampleRate: tracesSampleRateOption, tracesSamplerReturnValue: tracesSamplerReturnValueOption), profileSamplingV1Options: .init(profilesSampleRate: profilesSampleRateOption, profilesSamplerReturnValue: profilesSamplerReturnValueOption), continuousProfileV2Options: continuousProfileV2Options)

                            let expectedDecision = LaunchProfileOptions.validCombinations.contains(actualOptions)
                            XCTAssertEqual(expectedDecision, actualDecision, "Expected \(expectedDecision ? "" : "not ")to enable app launch profiling with options: LaunchProfileOptions(enableAppLaunchProfiling: \(enableAppLaunchProfilingOption), enableProfiling: \(enableProfilingOption), tracingOptions: .init(enableTracing: \(enableTracingOption), tracesSampleRate: \(String(describing: tracesSampleRateOption)), tracesSamplerReturnValue: \(String(describing: tracesSamplerReturnValueOption))), profileSamplingV1Options: .init(profilesSampleRate: \(String(describing: profilesSampleRateOption)), profilesSamplerReturnValue: \(String(describing: profilesSamplerReturnValueOption))), continuousProfileV2Options: \(String(describing: continuousProfileV2Options))) }")
//                            XCTAssertNotEqual(LaunchProfileOptions.validCombinations.contains(actualOptions), actualDecision)
                        }
                    }
                }
            }
        }

//        for testCase: (enableAppLaunchProfiling: Bool, enableTracing: Bool, tracesSampleRate: Int, profilesSampleRate: Int?, profilesSamplerReturnValue: Int?, shouldProfileLaunch: Bool) in [
//            // everything false/0
//            (enableAppLaunchProfiling: false, enableTracing: false, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            // change profilesSampleRate to 1
//            (enableAppLaunchProfiling: false, enableTracing: false, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            // change tracesSampleRate to 1
//            (enableAppLaunchProfiling: false, enableTracing: false, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: false, enableTracing: false, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            // enable continuous profiling by setting profilesSampleRate to nil
//            (enableAppLaunchProfiling: false, enableTracing: false, tracesSampleRate: 0, profilesSampleRate: nil, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: false, enableTracing: false, tracesSampleRate: 1, profilesSampleRate: nil, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            // change enableTracing to true
//            (enableAppLaunchProfiling: false, enableTracing: true, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: false, enableTracing: true, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: false, enableTracing: true, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: false, enableTracing: true, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: false, enableTracing: true, tracesSampleRate: 0, profilesSampleRate: nil, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: false, enableTracing: true, tracesSampleRate: 1, profilesSampleRate: nil, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            // change enableAppLaunchProfiling to true
//            (enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 0, profilesSampleRate: nil, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 1, profilesSampleRate: nil, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: 0, profilesSampleRate: nil, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: 1, profilesSampleRate: nil, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
//            // change profilesSamplerReturnValue to 1
//            (enableAppLaunchProfiling: false, enableTracing: false, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: false, enableTracing: false, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: false, enableTracing: false, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: false, enableTracing: false, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: false, enableTracing: false, tracesSampleRate: 0, profilesSampleRate: nil, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: false, enableTracing: false, tracesSampleRate: 1, profilesSampleRate: nil, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: false, enableTracing: true, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: false, enableTracing: true, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: false, enableTracing: true, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: false, enableTracing: true, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: false, enableTracing: true, tracesSampleRate: 0, profilesSampleRate: nil, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: false, enableTracing: true, tracesSampleRate: 1, profilesSampleRate: nil, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 0, profilesSampleRate: nil, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 1, profilesSampleRate: nil, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
//            (enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
//            (enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: 0, profilesSampleRate: nil, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
//            (enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: 1, profilesSampleRate: nil, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
//
//            // just those cases that had nil profilesSampleRate but nonnil profilesSamplerReturnValue, now with both as nil, which would enable launch profiling with continuous mode
//                (enableAppLaunchProfiling: false, enableTracing: false, tracesSampleRate: 0, profilesSampleRate: nil, profilesSamplerReturnValue: nil, shouldProfileLaunch: false),
//                (enableAppLaunchProfiling: false, enableTracing: false, tracesSampleRate: 1, profilesSampleRate: nil, profilesSamplerReturnValue: nil, shouldProfileLaunch: false),
//                (enableAppLaunchProfiling: false, enableTracing: true, tracesSampleRate: 0, profilesSampleRate: nil, profilesSamplerReturnValue: nil, shouldProfileLaunch: false),
//                (enableAppLaunchProfiling: false, enableTracing: true, tracesSampleRate: 1, profilesSampleRate: nil, profilesSamplerReturnValue: nil, shouldProfileLaunch: false),
//                (enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 0, profilesSampleRate: nil, profilesSamplerReturnValue: nil, shouldProfileLaunch: true),
//                (enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 1, profilesSampleRate: nil, profilesSamplerReturnValue: nil, shouldProfileLaunch: true),
//                (enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: 0, profilesSampleRate: nil, profilesSamplerReturnValue: nil, shouldProfileLaunch: true),
//                (enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: 1, profilesSampleRate: nil, profilesSamplerReturnValue: nil, shouldProfileLaunch: true),
//                (enableAppLaunchProfiling: false, enableTracing: false, tracesSampleRate: 0, profilesSampleRate: nil, profilesSamplerReturnValue: nil, shouldProfileLaunch: false),
//                (enableAppLaunchProfiling: false, enableTracing: false, tracesSampleRate: 1, profilesSampleRate: nil, profilesSamplerReturnValue: nil, shouldProfileLaunch: false),
//                (enableAppLaunchProfiling: false, enableTracing: true, tracesSampleRate: 0, profilesSampleRate: nil, profilesSamplerReturnValue: nil, shouldProfileLaunch: false),
//                (enableAppLaunchProfiling: false, enableTracing: true, tracesSampleRate: 1, profilesSampleRate: nil, profilesSamplerReturnValue: nil, shouldProfileLaunch: false),
//                (enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 0, profilesSampleRate: nil, profilesSamplerReturnValue: nil, shouldProfileLaunch: true),
//                (enableAppLaunchProfiling: true, enableTracing: false, tracesSampleRate: 1, profilesSampleRate: nil, profilesSamplerReturnValue: nil, shouldProfileLaunch: true),
//                (enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: 0, profilesSampleRate: nil, profilesSamplerReturnValue: nil, shouldProfileLaunch: true),
//                (enableAppLaunchProfiling: true, enableTracing: true, tracesSampleRate: 1, profilesSampleRate: nil, profilesSamplerReturnValue: nil, shouldProfileLaunch: true)
//        ] {
//            let options = Options()
//            options.enableAppLaunchProfiling = testCase.enableAppLaunchProfiling
//            Dynamic(options).enableTracing = testCase.enableTracing
//            options.tracesSampleRate = NSNumber(value: testCase.tracesSampleRate)
//            if let profilesSampleRate = testCase.profilesSampleRate {
//                options.profilesSampleRate = NSNumber(value: profilesSampleRate)
//            } else {
//                options.profilesSampleRate = nil
//            }
//            if let profilesSamplerReturnValue = testCase.profilesSamplerReturnValue {
//                options.profilesSampler = { _ in
//                    NSNumber(value: profilesSamplerReturnValue)
//                }
//            } else {
//                options.profilesSampler = nil
//            }
//            XCTAssertEqual(sentry_willProfileNextLaunch(options), testCase.shouldProfileLaunch, "Expected \(testCase.shouldProfileLaunch ? "" : "not ")to enable app launch profiling with options: { enableAppLaunchProfiling: \(testCase.enableAppLaunchProfiling), enableTracing: \(testCase.enableTracing), tracesSampleRate: \(testCase.tracesSampleRate), profilesSampleRate: \(String(describing: testCase.profilesSampleRate)), profilesSamplerReturnValue: \(String(describing: testCase.profilesSamplerReturnValue)) }")
//        }
    }
}

struct LaunchProfileOptions: Equatable {
    let enableAppLaunchProfiling: Bool
    let enableProfiling: Bool

    struct TracingOptions: Equatable {
        let enableTracing: Bool
        let tracesSampleRate: Float?
        let tracesSamplerReturnValue: Float?

        static func iterateCombinations(_ combo: (_ enableTracing: Bool, _ sampleRate: Float?, _ samplerReturnValue: Float?) -> Void) {
            for enableTracing in [true, false] {
                for sampleRate: Float? in [nil, 0, 1] {
                    for samplerReturnValue: Float? in [nil, 0, 1] {
                        combo(enableTracing, sampleRate, samplerReturnValue)
                    }
                }
            }
        }

        static let validCombinationsTransactionProfiling: [TracingOptions] = {
            var combos = [TracingOptions]()
            iterateCombinations { enableTracing, sampleRate, samplerReturnValue in
                if enableTracing == false && (sampleRate == nil || sampleRate == 0) && (samplerReturnValue == nil || samplerReturnValue == 0) { return }
                combos.append(TracingOptions(enableTracing: enableTracing, tracesSampleRate: sampleRate, tracesSamplerReturnValue: samplerReturnValue))
            }
            return combos
        }()

        static let validCombinationsContinuousProfilingV1: [TracingOptions] = {
            var combos = [TracingOptions]()
            iterateCombinations { enableTracing, tracesSampleRate, tracesSamplerReturnValue in
                combos.append(TracingOptions(enableTracing: enableTracing, tracesSampleRate: tracesSampleRate, tracesSamplerReturnValue: tracesSamplerReturnValue))
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
                if (sampleRate == nil || sampleRate == 0) && (samplerReturnValue == nil || samplerReturnValue == 0) { return }
                combos.append(ProfileSamplingV1Options(profilesSampleRate: sampleRate, profilesSamplerReturnValue: samplerReturnValue))
            }
            return combos
        }()

        static let validCombinationsContinuousProfilingV1: [ProfileSamplingV1Options] = {
            var combos = [ProfileSamplingV1Options]()
            iterateCombinations { sampleRate, samplerReturnValue in
                combos.append(ProfileSamplingV1Options(profilesSampleRate: sampleRate, profilesSamplerReturnValue: samplerReturnValue))
            }
            return combos
        }()

        static let validCombinationsContinuousProfilingV2ManualLifecycle: [ProfileSamplingV1Options] = {
            [ProfileSamplingV1Options(profilesSampleRate: nil, profilesSamplerReturnValue: nil)]
        }()

        static let validCombinationsContinuousProfilingV2TraceLifecycle: [ProfileSamplingV1Options] = validCombinationsContinuousProfilingV2ManualLifecycle
    }

    let profileSamplingV1Options: ProfileSamplingV1Options

    struct ContinuousProfileV2Options: Equatable {
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
    }

    let continuousProfileV2Options: ContinuousProfileV2Options?

    static let validCombinations: [LaunchProfileOptions] = {
        var combos = [LaunchProfileOptions]()
        for enableAppLaunchProfilingOption in [true, false] {
            for enableProfilingOption in [true, false] {
                for tracingOptions in TracingOptions.validCombinationsTransactionProfiling {
                    for profileSamplingV1Options in ProfileSamplingV1Options.validCombinationsTransactionProfiling {
                        combos.append(.init(enableAppLaunchProfiling: enableAppLaunchProfilingOption, enableProfiling: enableProfilingOption, tracingOptions: tracingOptions, profileSamplingV1Options: profileSamplingV1Options, continuousProfileV2Options: nil))
                    }
                }
                for tracingOptions in TracingOptions.validCombinationsContinuousProfilingV1 {
                    for profileSamplingV1Options in ProfileSamplingV1Options.validCombinationsContinuousProfilingV1 {
                        combos.append(.init(enableAppLaunchProfiling: enableAppLaunchProfilingOption, enableProfiling: enableProfilingOption, tracingOptions: tracingOptions, profileSamplingV1Options: profileSamplingV1Options, continuousProfileV2Options: nil))
                    }
                }
                for tracingOptions in TracingOptions.validCombinationsContinuousProfilingV2TraceLifecycle {
                    for profileSamplingV1Options in ProfileSamplingV1Options.validCombinationsContinuousProfilingV2TraceLifecycle {
                        for continuousProfilingV2Options in ContinuousProfileV2Options.validCombinationsTraceLifecycle {
                            combos.append(.init(enableAppLaunchProfiling: enableAppLaunchProfilingOption, enableProfiling: enableProfilingOption, tracingOptions: tracingOptions, profileSamplingV1Options: profileSamplingV1Options, continuousProfileV2Options: continuousProfilingV2Options))
                        }
                    }
                }
                for tracingOptions in TracingOptions.validCombinationsContinuousProfilingV2ManualLifecycle {
                    for profileSamplingV1Options in ProfileSamplingV1Options.validCombinationsContinuousProfilingV2ManualLifecycle {
                        for continuousProfilingV2Options in ContinuousProfileV2Options.validCombinationsManualLifecycle {
                            combos.append(.init(enableAppLaunchProfiling: enableAppLaunchProfilingOption, enableProfiling: enableProfilingOption, tracingOptions: tracingOptions, profileSamplingV1Options: profileSamplingV1Options, continuousProfileV2Options: continuousProfilingV2Options))
                        }
                    }
                }
            }
        }
        return combos
    }()
}

#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
