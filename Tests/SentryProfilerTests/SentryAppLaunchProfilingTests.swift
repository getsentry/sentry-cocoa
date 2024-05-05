import Nimble
import Quick
import SentryTestUtils
import XCTest

final class SentryAppLaunchProfilingSwiftTestsNormal: XCTestCase {
    func testShouldProfileLaunchBasedOnOptionsCombinations() {
        for testCase: (enableAppLaunchProfiling: Bool, enableTracing: Bool, enableContinuousProfiling: Bool, tracesSampleRate: Int, profilesSampleRate: Int, shouldProfileLaunch: Bool) in [
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, shouldProfileLaunch: false),
            
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, shouldProfileLaunch: false),
            
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 1, shouldProfileLaunch: false),
            
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, shouldProfileLaunch: false),
            
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, shouldProfileLaunch: false),
            
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 1, shouldProfileLaunch: false),
            
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, shouldProfileLaunch: false),
            
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, shouldProfileLaunch: false),
            
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 1, shouldProfileLaunch: true),
            
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, shouldProfileLaunch: false),
            
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, shouldProfileLaunch: true),
            
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 1, shouldProfileLaunch: true)
        ] {
            let options = Options()
            options.enableAppLaunchProfiling = testCase.enableAppLaunchProfiling
            options.enableTracing = testCase.enableTracing
            options.enableContinuousProfiling = testCase.enableContinuousProfiling
            options.tracesSampleRate = NSNumber(value: testCase.tracesSampleRate)
            options.profilesSampleRate = NSNumber(value: testCase.profilesSampleRate)
            XCTAssertEqual(sentry_willProfileNextLaunch(options), testCase.shouldProfileLaunch, "Expected \(testCase.shouldProfileLaunch ? "" : "not ")to enable app launch profiling with options: { enableAppLaunchProfiling: \(testCase.enableAppLaunchProfiling); enableTracing: \(testCase.enableTracing); enableContinuousProfiling: \(testCase.enableContinuousProfiling); tracesSampleRate: \(testCase.tracesSampleRate); profilesSampleRate: \(testCase.profilesSampleRate) }")
        }
    }
}

//swiftlint:disable todo
/**
 * Test how combinations of the following options interact to return the correct value for `sentry_shouldProfileNextLaunch`
 * - `enableLaunchProfiling`
 * - `enableTracing`
 * -  `enableContinuousProfiling`
 * - `tracesSampleRate`
 * - `profilesSampleRate`
 *
 * - TODO: `profilesSampler`
 * - TODO: setting `tracesSampleRate` before `enableTracing`?
 */
final class SentryAppLaunchProfilingSwiftTests: QuickSpec {
    static var options: Options!
    
    override class func spec() {
        beforeEach { options = Options() }
        describe("With launch profiling disabled") {
            beforeEach { options.enableAppLaunchProfiling = false }
            _varying_enableTracing_neverProfilesLaunch()
        }
        describe("With launch profiling enabled") {
            beforeEach { options.enableAppLaunchProfiling = true }
            describe("With tracing manually disabled") {
                beforeEach { options.enableTracing = false }
                describe("With continuous profiling disabled") {
                    beforeEach { options.enableContinuousProfiling = false }
                    _varying_tracesSampleRate(when0: false, when1: false)
                }
                describe("With continuous profiling enabled") {
                    beforeEach { options.enableContinuousProfiling = true }
                    _varying_tracesSampleRate(when0: false, when1: true)
                }
            }
            describe("With tracing manually enabled") {
                beforeEach { options.enableTracing = true }
                describe("With continuous profiling disabled") {
                    beforeEach { options.enableContinuousProfiling = false }
                    describe("With traces sample rate of 0") {
                        beforeEach { options.tracesSampleRate = 0 }
                        _varying_profilesSampleRate(when0: false, when1: false)
                    }
                    describe("With traces sample rate of 1") {
                        beforeEach { options.tracesSampleRate = 1 }
                        _varying_profilesSampleRate(when0: false, when1: true)
                    }
                }
                describe("With continuous profiling enabled") {
                    beforeEach { options.enableContinuousProfiling = true }
                    _varying_tracesSampleRate(when0: false, when1: true)
                }
            }
        }
    }
}

private extension SentryAppLaunchProfilingSwiftTests {
    class func _varying_enableTracing_neverProfilesLaunch() {
        describe("With tracing manually disabled") {
            beforeEach { options.enableTracing = false }
            _varying_enableContinuousProfiling_neverProfilesLaunch()
        }
        describe("With tracing manually enabled") {
            beforeEach { options.enableTracing = true }
            _varying_enableContinuousProfiling_neverProfilesLaunch()
        }
    }
    
    class func _varying_profilesSampleRate(when0: Bool, when1: Bool) {
        describe("With profiles sample rate of 0") {
            beforeEach { options.profilesSampleRate = 0 }
            it("Should not enable launch profiling") {
                expect(sentry_willProfileNextLaunch(options)) == when0
            }
        }
        describe("With profiles sample rate of 1") {
            beforeEach { options.profilesSampleRate = 1 }
            it("Should not enable launch profiling") {
                expect(sentry_willProfileNextLaunch(options)) == when1
            }
        }
    }
    
    class func _varying_tracesSampleRate(when0: Bool, when1: Bool) {
        describe("With traces sample rate of 0") {
            beforeEach { options.tracesSampleRate = 0 }
            _varying_profilesSampleRate(when0: when0, when1: when1)
        }
        describe("With traces sample rate of 1") {
            beforeEach { options.tracesSampleRate = 1 }
            _varying_profilesSampleRate(when0: when0, when1: when1)
        }
    }
    
    class func _varying_enableContinuousProfiling_neverProfilesLaunch() {
        describe("With continuous profiling disabled") {
            beforeEach { options.enableContinuousProfiling = false }
            _varying_tracesSampleRate(when0: false, when1: false)
        }
        describe("With continuous profiling enabled") {
            beforeEach { options.enableContinuousProfiling = true }
            _varying_tracesSampleRate(when0: false, when1: false)
        }
    }
}
//swiftlint:enable todo
