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
        describe("With launch profiling disabled") {
            let options = Options()
            options.enableAppLaunchProfiling = false
            describe("With tracing manually disabled") {
                options.enableTracing = false
                describe("With continuous profiling disabled") {
                    options.enableContinuousProfiling = false
                    describe("With traces sample rate of 0") {
                        options.tracesSampleRate = 0
                        describe("With profiles sample rate of 0") {
                            options.profilesSampleRate = 0
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            options.profilesSampleRate = 1
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                    }
                    describe("With traces sample rate of 1") {
                        options.tracesSampleRate = 1
                        describe("With profiles sample rate of 0") {
                            options.profilesSampleRate = 0
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            options.profilesSampleRate = 1
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                    }
                }
                describe("With continuous profiling enabled") {
                    options.enableContinuousProfiling = true
                    describe("With traces sample rate of 0") {
                        options.tracesSampleRate = 0
                        describe("With profiles sample rate of 0") {
                            options.profilesSampleRate = 0
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            options.profilesSampleRate = 1
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                    }
                    describe("With traces sample rate of 1") {
                        options.tracesSampleRate = 1
                        describe("With profiles sample rate of 0") {
                            options.profilesSampleRate = 0
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            options.profilesSampleRate = 1
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                    }
                }
            }
            describe("With tracing manually enabled") {
                options.enableTracing = true
                describe("With continuous profiling disabled") {
                    options.enableContinuousProfiling = false
                    describe("With traces sample rate of 0") {
                        options.tracesSampleRate = 0
                        describe("With profiles sample rate of 0") {
                            options.profilesSampleRate = 0
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            options.profilesSampleRate = 1
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                    }
                    describe("With traces sample rate of 1") {
                        options.tracesSampleRate = 1
                        describe("With profiles sample rate of 0") {
                            options.profilesSampleRate = 0
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            options.profilesSampleRate = 1
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                    }
                }
                describe("With continuous profiling enabled") {
                    options.enableContinuousProfiling = true
                    describe("With traces sample rate of 0") {
                        options.tracesSampleRate = 0
                        describe("With profiles sample rate of 0") {
                            options.profilesSampleRate = 0
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            options.profilesSampleRate = 1
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                    }
                    describe("With traces sample rate of 1") {
                        options.tracesSampleRate = 1
                        describe("With profiles sample rate of 0") {
                            options.profilesSampleRate = 0
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            options.profilesSampleRate = 1
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                    }
                }
            }
        }
        describe("With launch profiling enabled") {
            let options = Options()
            options.enableAppLaunchProfiling = true
            describe("With tracing manually disabled") {
                options.enableTracing = false
                describe("With continuous profiling disabled") {
                    options.enableContinuousProfiling = false
                    describe("With traces sample rate of 0") {
                        options.tracesSampleRate = 0
                        describe("With profiles sample rate of 0") {
                            options.profilesSampleRate = 0
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            options.profilesSampleRate = 1
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                    }
                    describe("With traces sample rate of 1") {
                        options.tracesSampleRate = 1
                        describe("With profiles sample rate of 0") {
                            options.profilesSampleRate = 0
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            options.profilesSampleRate = 1
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                    }
                }
                describe("With continuous profiling enabled") {
                    options.enableContinuousProfiling = true
                    describe("With traces sample rate of 0") {
                        options.tracesSampleRate = 0
                        describe("With profiles sample rate of 0") {
                            options.profilesSampleRate = 0
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            options.profilesSampleRate = 1
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beTrue())
                            }
                        }
                    }
                    describe("With traces sample rate of 1") {
                        options.tracesSampleRate = 1
                        describe("With profiles sample rate of 0") {
                            options.profilesSampleRate = 0
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            options.profilesSampleRate = 1
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beTrue())
                            }
                        }
                    }
                }
            }
            describe("With tracing manually enabled") {
                options.enableTracing = true
                describe("With continuous profiling disabled") {
                    options.enableContinuousProfiling = false
                    describe("With traces sample rate of 0") {
                        options.tracesSampleRate = 0
                        describe("With profiles sample rate of 0") {
                            options.profilesSampleRate = 0
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            options.profilesSampleRate = 1
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                    }
                    describe("With traces sample rate of 1") {
                        options.tracesSampleRate = 1
                        describe("With profiles sample rate of 0") {
                            options.profilesSampleRate = 0
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            options.profilesSampleRate = 1
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beTrue())
                            }
                        }
                    }
                }
                describe("With continuous profiling enabled") {
                    options.enableContinuousProfiling = true
                    describe("With traces sample rate of 0") {
                        options.tracesSampleRate = 0
                        describe("With profiles sample rate of 0") {
                            options.profilesSampleRate = 0
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            options.profilesSampleRate = 1
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beTrue())
                            }
                        }
                    }
                    describe("With traces sample rate of 1") {
                        options.tracesSampleRate = 1
                        describe("With profiles sample rate of 0") {
                            options.profilesSampleRate = 0
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beFalse())
                            }
                        }
                        describe("With profiles sample rate of 1") {
                            options.profilesSampleRate = 1
                            it("Should not enable launch profiling") {
                                expect(sentry_willProfileNextLaunch(options)).to(beTrue())
                            }
                        }
                    }
                }
            }
        }
    }
}
//swiftlint:enable todo
