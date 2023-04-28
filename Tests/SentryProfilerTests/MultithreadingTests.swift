import XCTest

final class MultithreadingTests: XCTestCase {}

let system = SentrySystemWrapper()

extension MultithreadingTests {
    func work() {
        var results = [Double]()
        for _ in 0..<1_000 {
            let a = UInt64(arc4random())
            let b = UInt64(arc4random())
            let c = a + b
            let d = a > b ? a - b : b - a
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

    func testQueuesAndThreads() {
//        let privateUtilityQueue = DispatchQueue(label: "private utility", qos: .utility)
        let privateBackgroundQueue = DispatchQueue(label: "private bg", qos: .background)

        func scheduleBlocks(_ queue: DispatchQueue, _ number: Int, _ queueName: String, _ exp: XCTestExpectation, slow: Bool = false, work: Bool = true) {
            for _ in 0..<number {
                queue.async {
                    if slow { sleep(5) }
                    if work { self.work() }
//                    print("queue: \(queueName); thread: \(String(reflecting: Thread.current));\ncpu usage: \(String(reflecting: try! system.cpuUsagePerCore()));\ncpu info:\n\(String(reflecting: try! system.cpuInfo()))")
                    exp.fulfill()
                }
            }
        }

        let qosClasses = 2
        let workUnits = 1_000
        let expectedFulfillmentCount = qosClasses * workUnits

        let multithreaded = benchmark {
            let exp = self.expectation(description: "all blocks finish")
            exp.expectedFulfillmentCount = expectedFulfillmentCount

            [
                "main": DispatchQueue.main,
//                "global background": DispatchQueue.global(qos: .background),
//                "global user initiated": DispatchQueue.global(qos: .userInitiated),
//                "global utility": DispatchQueue.global(qos: .utility),
//                "private serial utility": privateUtilityQueue,
                "private serial background": privateBackgroundQueue
            ].forEach {
                scheduleBlocks($0.value, workUnits, $0.key, exp)
            }

            self.waitForExpectations(timeout: 10)
        }

        let mainThreadOnly = benchmark {
            let exp = self.expectation(description: "all blocks finish")
            exp.expectedFulfillmentCount = expectedFulfillmentCount
            scheduleBlocks(DispatchQueue.main, expectedFulfillmentCount, "main", exp)
            self.waitForExpectations(timeout: 10)
        }

//        print("multithreaded: \(multithreaded)")
//        print("mainThreadOnly: \(mainThreadOnly)")
        print("multithreaded - main thread only: \(multithreaded.diff(other: mainThreadOnly))")
    }

    func testFail() {
        XCTFail()
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
    let averageWallClockTime = dispatch_benchmark(10) {
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
