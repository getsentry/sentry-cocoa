import XCTest

final class MultithreadingTests: XCTestCase {
    let qosClasses = 3
    let workUnits = 1_000
    lazy var expectedFulfillmentCount = qosClasses * workUnits

    let benchmarkIterations = 10
    let slowWorkSleepDuration: UInt32 = 5

    func testMainQueueOnly() {
        print(mainQueueOnly())
    }

    func testMultiqueue() {
        print(multiqueue())
    }

    func testMultiqueueVsMainQueueOnly() {
        let multiqueue = multiqueue()
        let mainQueueOnly = mainQueueOnly()

//        print("multithreaded: \(multithreaded)")
//        print("mainThreadOnly: \(mainThreadOnly)")
        print("multithreaded - main thread only: \(multiqueue.diff(other: mainQueueOnly))")
    }
}

let system = SentrySystemWrapper()

extension MultithreadingTests {
    func work() {
        var results = [Double]()
        for _ in 0..<1_000 {
            let a = max(UInt64(arc4random()), 1)
            let b = max(UInt64(arc4random()), 1)
            let c = a + b
            let d = max(a > b ? a - b : b - a, 1)
            let e = c / d
            let f = d / c
            let g = a % b
            let h = b % a
            let i = e * g
            let j = f * h
            let k = e * h
            let l = f * g
            let m = sqrt(Double(a))
            let n = sqrt(Double(b))
            let o = m * n
            let p = atan2(m, n)
            results.append(Double(i + j + k + l) + o + p)
        }
        let _ = results.average
    }

    func workUnit(exp: XCTestExpectation, slow: Bool, doWork: Bool) {
        if slow { sleep(slowWorkSleepDuration) }
        if doWork { work() }
        exp.fulfill()
    }

    func scheduleBlocks(_ queue: DispatchQueue, _ number: Int, _ queueName: String, _ exp: XCTestExpectation, slow: Bool = false, doWork: Bool = true) {
        for _ in 0..<number {
            queue.async {
//                print("time: \(getAbsoluteTime()); queue: \(queueName); thread: \(pthread_mach_thread_np(pthread_self()))\(Thread.current.isMainThread ? " (main)" : "")")
//                print("cpu usage: \(String(reflecting: try! system.cpuUsagePerCore()))")
//                print("cpu info:\n\(String(reflecting: try! system.cpuInfo()))")
                self.workUnit(exp: exp, slow: slow, doWork: doWork)
            }
        }
    }

    func multiqueue() -> BenchmarkStats {
//        let privateUtilityQueue = DispatchQueue(label: "private utility", qos: .utility, attributes: [.initiallyInactive])
        let privateBackgroundQueue = DispatchQueue(label: "private bg", qos: .background, attributes: [.initiallyInactive])
        let privateUserInteractiveQueue = DispatchQueue(label: "private user interactive", qos: .userInteractive, attributes: [.initiallyInactive, .concurrent])

        return benchmark {
            let exp = self.expectation(description: "all blocks finish")
            exp.expectedFulfillmentCount = self.expectedFulfillmentCount

            // load up all the queues with work items
            let queues = [
                "main": DispatchQueue.main,
//                "global background": DispatchQueue.global(qos: .background),
//                "global user initiated": DispatchQueue.global(qos: .userInitiated),
//                "global utility": DispatchQueue.global(qos: .utility),
//                "private serial utility": privateUtilityQueue,
                "private serial background": privateBackgroundQueue,
                "private user interactive": privateUserInteractiveQueue
            ]
            queues.forEach {
                self.scheduleBlocks($0.value, self.workUnits, $0.key, exp)
            }

            // start all the queues simultaneously
            let queueStartQueue = DispatchQueue(label: "scheduling queue", qos: .userInteractive, attributes: [.concurrent, .initiallyInactive])
            queues.values.forEach { queue in
                queueStartQueue.async {
                    queue.activate()
                }
            }
            queueStartQueue.activate()

            self.waitForExpectations(timeout: 10)
        }
    }

    func mainQueueOnly() -> BenchmarkStats {
        benchmark {
            let exp = self.expectation(description: "all blocks finish")
            exp.expectedFulfillmentCount = self.expectedFulfillmentCount
            self.scheduleBlocks(DispatchQueue.main, self.expectedFulfillmentCount, "main", exp)
            self.waitForExpectations(timeout: 10)
        }
    }

    typealias ThreadUsage = (time: UInt64, usagePercent: Double)

    struct BenchmarkStats: CustomStringConvertible {
        var averageCPUPowerUsage_nJ: Double
        var averageGPUPowerUsage_nJ: Double
        var averageProcessorSwitches: Double
        var averageWallClockTime_ns: Int64
        var averageContextSwitches: Double
    //    var averageCPUUsagesPerThread: [UInt64: ThreadUsage]

        var description: String {
            String([
                "average total CPU power usage: \(averageCPUPowerUsage_nJ) nJ",
                "average total GPU power usage: \(averageGPUPowerUsage_nJ) nJ",
                "average processor switches: \(averageProcessorSwitches)",
                "average wall clock time: \(averageWallClockTime_ns) ns",
                "average context switches: \(averageContextSwitches)"
            ].joined(separator: "\n"))
        }

        // self - other
        func diff(other: BenchmarkStats) -> BenchmarkStats {
            return BenchmarkStats(
                averageCPUPowerUsage_nJ: averageCPUPowerUsage_nJ - other.averageCPUPowerUsage_nJ,
                averageGPUPowerUsage_nJ: averageGPUPowerUsage_nJ - other.averageGPUPowerUsage_nJ,
                averageProcessorSwitches: averageProcessorSwitches - other.averageProcessorSwitches,
                averageWallClockTime_ns: averageWallClockTime_ns - other.averageWallClockTime_ns,
                averageContextSwitches: averageContextSwitches - other.averageContextSwitches
            )
        }
    }

    func benchmark(block: @escaping () -> Void) -> BenchmarkStats {
        var cpuPowerUsages = [UInt64]()
        var gpuPowerUsages = [UInt64]()
        var pswitches = [UInt64]()
        var contextSwitches = [UInt64]()
    //    var cpuTimePerThread = [SentryCPUUsagePerThread]()
        var cpuTicks = [UInt64]()
        let averageWallClockTime = dispatch_benchmark(benchmarkIterations) {
            let startingPowerUsage = try! system.powerUsage()
            let startingContextSwitches = try! system.numContextSwitches()
    //        let startingCPUUsagePerThread = try! system.cpuUsagePerThread()
            let startingCPUTicks = try! system.cpuTicks()

            block()

            let endingPowerUsage = try! system.powerUsage()
            let totalCPUPowerUsed = endingPowerUsage.totalCPU() - startingPowerUsage.totalCPU()
            cpuPowerUsages.append(totalCPUPowerUsed)

            let totalGPUPowerUsed = endingPowerUsage.totalGPU() - startingPowerUsage.totalGPU()
            gpuPowerUsages.append(totalGPUPowerUsed)

            let totalPswitches = endingPowerUsage.info.task_pset_switches - startingPowerUsage.info.task_pset_switches
            pswitches.append(totalPswitches)

            let endingContextSwitches = try! system.numContextSwitches()
            let totalContextSwitches = endingContextSwitches.uint64Value - startingContextSwitches.uint64Value
            contextSwitches.append(totalContextSwitches)

    //        let endingCPUUsagePerThread = try! system.cpuUsagePerThread()
    //        let totalCPUUsagePerThread = SentryCPUUsagePerThread()
    //        endingCPUUsagePerThread.usages.allKeys.forEach { key in
    //            guard let start = startingCPUUsagePerThread.usages[key] as? SentryThreadCPUUsage else { return }
    //            guard let end = endingCPUUsagePerThread.usages[key] as? SentryThreadCPUUsage else { return }
    //            let system = end.data.system_time.seconds - start.data.system_time.seconds + end.data.system_time.microseconds - start.data.system_time.microseconds
    //            let user = end.data.user_time.seconds - start.data.user_time.seconds + end.data.user_time.microseconds - start.data.user_time.microseconds
    //            let usage = end.data.cpu_usage - start.data.cpu_usage
    //            totalCPUUsagePerThread.usages[key] = (system, user, usage)
    //        }
    //        cpuTimePerThread.append(totalCPUUsagePerThread)

            let endingCPUTicks = try! system.cpuTicks()
            let totalCPUTicks = endingCPUTicks.total() - startingCPUTicks.total()
            cpuTicks.append(totalCPUTicks)
        }

    //    var threadCounts = [UInt64: UInt64]()
    //    let totalUsagePerThread = cpuTimePerThread.reduce(into: [UInt64: ThreadUsage]) { partialResult, next in
    //
    //    }

        return BenchmarkStats(averageCPUPowerUsage_nJ: cpuPowerUsages.average, averageGPUPowerUsage_nJ: gpuPowerUsages.average, averageProcessorSwitches: pswitches.average, averageWallClockTime_ns: Int64(averageWallClockTime), averageContextSwitches: contextSwitches.average)
    }
}

extension Array where Element == UInt64 {
    var average: Double {
        Double(reduce(0, +)) / Double(count)
    }
}

extension Array where Element == Double {
    var average: Double {
        reduce(0, +) / Double(count)
    }
}
