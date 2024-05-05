import Nimble
import Quick
import SentryTestUtils

//swiftlint:disable todo
/**
 * Test how combinations of the following options interact to return the correct value for `sentry_shouldProfileNextLaunch`
 * - `enableLaunchProfiling`
 * - `enableTraces`
 * -  `enableContinuousProfiling`
 * - `tracesSampleRate`
 * - `profilesSampleRate`
 *
 * - TODO: `profilesSampler`
 * - TODO: setting `tracesSampleRate` before `enableTraces`?
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
