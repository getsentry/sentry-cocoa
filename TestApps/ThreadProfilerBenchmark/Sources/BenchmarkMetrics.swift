@_spi(Private) import Sentry
import Darwin
import Foundation

struct ProfilerStatistics {
    var samples = 0
    var threads = 0
    var frames = 0
    var failures = 0
    var captureDurations: [Double] = []

    init() {}

    init(_ result: SentryThreadProfilerBenchmark.Result) {
        samples = result.samples
        threads = result.threads
        frames = result.frames
        failures = result.failures
        captureDurations = result.captureDurations
    }
}

struct BenchmarkResult {
    let wallSeconds: Double
    let cpuSeconds: Double
    let tickGaps: [Double]
    var profiler = ProfilerStatistics()

    var cpuPercent: Double { cpuSeconds / wallSeconds * 100 }
    var updatesPerSecond: Double { Double(tickGaps.count) / wallSeconds }

    func tickGapPercentile(_ fraction: Double) -> Double {
        Self.percentile(tickGaps, fraction) * 1_000
    }

    func capturePercentile(_ fraction: Double) -> Double {
        Self.percentile(profiler.captureDurations, fraction)
    }

    static func aggregate(_ runs: [Self]) -> Self {
        var stats = ProfilerStatistics()
        for run in runs {
            stats.samples += run.profiler.samples
            stats.threads += run.profiler.threads
            stats.frames += run.profiler.frames
            stats.failures += run.profiler.failures
            stats.captureDurations.append(contentsOf: run.profiler.captureDurations)
        }
        return Self(
            wallSeconds: runs.reduce(0) { $0 + $1.wallSeconds },
            cpuSeconds: runs.reduce(0) { $0 + $1.cpuSeconds },
            tickGaps: runs.flatMap(\.tickGaps), profiler: stats
        )
    }

    private static func percentile(_ values: [Double], _ fraction: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        return sorted[max(0, Int(ceil(Double(sorted.count) * fraction)) - 1)]
    }
}

@MainActor
final class BenchmarkMetrics {
    private let dateProvider: SentryCurrentDateProvider
    private var isMeasuring = false
    private var lastTick = 0.0
    private var started = 0.0
    private var cpuStarted = 0.0
    private var tickGaps: [Double] = []

    init(dateProvider: SentryCurrentDateProvider) {
        self.dateProvider = dateProvider
    }

    func start() {
        tickGaps = []
        tickGaps.reserveCapacity(2_000)
        cpuStarted = processCPUSeconds()
        started = now()
        lastTick = started
        isMeasuring = true
    }

    func tick() {
        guard isMeasuring else { return }
        let currentTime = now()
        if tickGaps.count < 2_000 {
            tickGaps.append(currentTime - lastTick)
        }
        lastTick = currentTime
    }

    func finish() -> BenchmarkResult {
        let wall = now() - started
        let cpu = processCPUSeconds() - cpuStarted
        isMeasuring = false
        return BenchmarkResult(wallSeconds: wall, cpuSeconds: cpu, tickGaps: tickGaps)
    }

    private func now() -> Double {
        Double(dateProvider.getAbsoluteTime()) / 1_000_000_000
    }

    private func processCPUSeconds() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        return Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1_000_000
            + Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000
    }
}
