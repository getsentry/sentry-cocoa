import XCTest
import Quick

final class SentryAppLaunchProfilingTests: XCTestCase {
    func testAppLaunchOptions() {
        // enableLaunchProfiling(F)
        //     enableTraces(F)
        //         enableContinuousProfiling(F)
        //             tracesSampleRate(0)
        //                 profilesSampleRate(0): no launch profiling
        //                 profilesSampleRate(1): no launch profiling
        //             tracesSampleRate(1)
        //                 profilesSampleRate(0): no launch profiling
        //                 profilesSampleRate(1): no launch profiling
        //         enableContinuousProfiling(T)
        //             tracesSampleRate(0)
        //                 profilesSampleRate(0): no launch profiling
        //                 profilesSampleRate(1): no launch profiling
        //             tracesSampleRate(1)
        //                 profilesSampleRate(0): no launch profiling
        //                 profilesSampleRate(1): no launch profiling
        //     enableTraces(T)
        //         enableContinuousProfiling(F)
        //             tracesSampleRate(0)
        //                 profilesSampleRate(0): no launch profiling
        //                 profilesSampleRate(1): no launch profiling
        //             tracesSampleRate(1)
        //                 profilesSampleRate(0): no launch profiling
        //                 profilesSampleRate(1): no launch profiling
        //         enableContinuousProfiling(T)
        //             tracesSampleRate(0)
        //                 profilesSampleRate(0): no launch profiling
        //                 profilesSampleRate(1): no launch profiling
        //             tracesSampleRate(1)
        //                 profilesSampleRate(0): no launch profiling
        //                 profilesSampleRate(1): no launch profiling
        // enableLaunchProfiling(T)
        //     enableTraces(F)
        //         enableContinuousProfiling(F)
        //             tracesSampleRate(0)
        //                 profilesSampleRate(0): no launch profiling
        //                 profilesSampleRate(1): no launch profiling
        //             tracesSampleRate(1)
        //                 profilesSampleRate(0): no launch profiling
        //                 profilesSampleRate(1): no launch profiling
        //         enableContinuousProfiling(T)
        //             tracesSampleRate(0)
        //                 profilesSampleRate(0): no launch profiling
        //                 profilesSampleRate(1): continuous launch profile
        //             tracesSampleRate(1)
        //                 profilesSampleRate(0): no launch profiling
        //                 profilesSampleRate(1): continuous launch profile
        //     enableTraces(T)
        //         enableContinuousProfiling(F)
        //             tracesSampleRate(0)
        //                 profilesSampleRate(0): no launch profiling
        //                 profilesSampleRate(1): no launch profiling
        //             tracesSampleRate(1)
        //                 profilesSampleRate(0): no launch profiling
        //                 profilesSampleRate(1): legacy launch profile
        //         enableContinuousProfiling(T)
        //             tracesSampleRate(0)
        //                 profilesSampleRate(0): no launch profiling
        //                 profilesSampleRate(1): continuous launch profile
        //             tracesSampleRate(1)
        //                 profilesSampleRate(0): no launch profiling
        //                 profilesSampleRate(1): continuous launch profile
    }
}
