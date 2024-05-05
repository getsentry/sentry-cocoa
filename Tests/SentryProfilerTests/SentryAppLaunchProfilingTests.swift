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
    override class func spec() {
        var options: Options!
        beforeEach { options = Options() }
        describe("With launch profiling disabled") {
            beforeEach { options.enableAppLaunchProfiling = false }
            describe("With tracing manually disabled") {
                beforeEach { options.enableTracing = false }
                describe("With continuous profiling disabled") {
                    beforeEach { options.enableContinuousProfiling = false }
                    describe("With traces sample rate of 0") {
                        beforeEach { options.tracesSampleRate = 0 }
                        describe("With profiles sample rate of 0") {
                            beforeEach { options.profilesSampleRate = 0 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            beforeEach { options.profilesSampleRate = 1 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                    }
                    describe("With traces sample rate of 1") {
                        beforeEach { options.tracesSampleRate = 1 }
                        describe("With profiles sample rate of 0") {
                            beforeEach { options.profilesSampleRate = 0 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            beforeEach { options.profilesSampleRate = 1 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                    }
                }
                describe("With continuous profiling enabled") {
                    beforeEach { options.enableContinuousProfiling = true }
                    describe("With traces sample rate of 0") {
                        beforeEach { options.tracesSampleRate = 0 }
                        describe("With profiles sample rate of 0") {
                            beforeEach { options.profilesSampleRate = 0 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            beforeEach { options.profilesSampleRate = 1 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                    }
                    describe("With traces sample rate of 1") {
                        beforeEach { options.tracesSampleRate = 1 }
                        describe("With profiles sample rate of 0") {
                            beforeEach { options.profilesSampleRate = 0 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            beforeEach { options.profilesSampleRate = 1 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                    }
                }
            }
            describe("With tracing manually enabled") {
                beforeEach { options.enableTracing = true }
                describe("With continuous profiling disabled") {
                    beforeEach { options.enableContinuousProfiling = false }
                    describe("With traces sample rate of 0") {
                        beforeEach { options.tracesSampleRate = 0 }
                        describe("With profiles sample rate of 0") {
                            beforeEach { options.profilesSampleRate = 0 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            beforeEach { options.profilesSampleRate = 1 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                    }
                    describe("With traces sample rate of 1") {
                        beforeEach { options.tracesSampleRate = 1 }
                        describe("With profiles sample rate of 0") {
                            beforeEach { options.profilesSampleRate = 0 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            beforeEach { options.profilesSampleRate = 1 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                    }
                }
                describe("With continuous profiling enabled") {
                    beforeEach { options.enableContinuousProfiling = true }
                    describe("With traces sample rate of 0") {
                        beforeEach { options.tracesSampleRate = 0 }
                        describe("With profiles sample rate of 0") {
                            beforeEach { options.profilesSampleRate = 0 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            beforeEach { options.profilesSampleRate = 1 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                    }
                    describe("With traces sample rate of 1") {
                        beforeEach { options.tracesSampleRate = 1 }
                        describe("With profiles sample rate of 0") {
                            beforeEach { options.profilesSampleRate = 0 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            beforeEach { options.profilesSampleRate = 1 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                    }
                }
            }
        }
        describe("With launch profiling enabled") {
            beforeEach { options.enableAppLaunchProfiling = true }
            describe("With tracing manually disabled") {
                beforeEach { options.enableTracing = false }
                describe("With continuous profiling disabled") {
                    beforeEach { options.enableContinuousProfiling = false }
                    describe("With traces sample rate of 0") {
                        beforeEach { options.tracesSampleRate = 0 }
                        describe("With profiles sample rate of 0") {
                            beforeEach { options.profilesSampleRate = 0 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            beforeEach { options.profilesSampleRate = 1 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                    }
                    describe("With traces sample rate of 1") {
                        beforeEach { options.tracesSampleRate = 1 }
                        describe("With profiles sample rate of 0") {
                            beforeEach { options.profilesSampleRate = 0 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            beforeEach { options.profilesSampleRate = 1 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                    }
                }
                describe("With continuous profiling enabled") {
                    beforeEach { options.enableContinuousProfiling = true }
                    describe("With traces sample rate of 0") {
                        beforeEach { options.tracesSampleRate = 0 }
                        describe("With profiles sample rate of 0") {
                            beforeEach { options.profilesSampleRate = 0 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            beforeEach { options.profilesSampleRate = 1 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == true
                            }
                        }
                    }
                    describe("With traces sample rate of 1") {
                        beforeEach { options.tracesSampleRate = 1 }
                        describe("With profiles sample rate of 0") {
                            beforeEach { options.profilesSampleRate = 0 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            beforeEach { options.profilesSampleRate = 1 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == true
                            }
                        }
                    }
                }
            }
            describe("With tracing manually enabled") {
                beforeEach { options.enableTracing = true }
                describe("With continuous profiling disabled") {
                    beforeEach { options.enableContinuousProfiling = false }
                    describe("With traces sample rate of 0") {
                        beforeEach { options.tracesSampleRate = 0 }
                        describe("With profiles sample rate of 0") {
                            beforeEach { options.profilesSampleRate = 0 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            beforeEach { options.profilesSampleRate = 1 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                    }
                    describe("With traces sample rate of 1") {
                        beforeEach { options.tracesSampleRate = 1 }
                        describe("With profiles sample rate of 0") {
                            beforeEach { options.profilesSampleRate = 0 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            beforeEach { options.profilesSampleRate = 1 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == true
                            }
                        }
                    }
                }
                describe("With continuous profiling enabled") {
                    beforeEach { options.enableContinuousProfiling = true }
                    describe("With traces sample rate of 0") {
                        beforeEach { options.tracesSampleRate = 0 }
                        describe("With profiles sample rate of 0") {
                            beforeEach { options.profilesSampleRate = 0 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            beforeEach { options.profilesSampleRate = 1 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == true
                            }
                        }
                    }
                    describe("With traces sample rate of 1") {
                        beforeEach { options.tracesSampleRate = 1 }
                        describe("With profiles sample rate of 0") {
                            beforeEach { options.profilesSampleRate = 0 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == false
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            beforeEach { options.profilesSampleRate = 1 }
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)) == true
                            }
                        }
                    }
                }
            }
        }
    }
}
//swiftlint:enable todo
