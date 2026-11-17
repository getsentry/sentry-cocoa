@_spi(Private) import Sentry
import Foundation
import Observation

struct BenchmarkItem: Identifiable {
    let id: Int
    let title: String
    let score: Int

    static func catalog(revision: Int) -> [Self] {
        (0..<240).map { index in
            Self(id: index, title: "Activity \(index + 1)", score: (index * 37 + revision * 11) % 101)
        }.sorted {
            $0.score == $1.score ? $0.id < $1.id : $0.score > $1.score
        }
    }
}

@MainActor
@Observable
final class BenchmarkSession {
    static let trialCount = 5

    private(set) var isRunning = false
    private(set) var activityRunning = false
    private(set) var status = "Ready to compare baseline with 50 ms all-thread profiling."
    private(set) var report = ""
    private(set) var animationStart: Date
    private(set) var revision = 0
    private(set) var items = BenchmarkItem.catalog(revision: 0)

    @ObservationIgnored private var workTimer: Timer?
    @ObservationIgnored private var tickCount = 0
    @ObservationIgnored private let dateProvider: SentryCurrentDateProvider
    @ObservationIgnored private let metrics: BenchmarkMetrics

    init(dateProvider: SentryCurrentDateProvider = SentryDependencyContainer.sharedInstance().dateProvider) {
        self.dateProvider = dateProvider
        self.metrics = BenchmarkMetrics(dateProvider: dateProvider)
        self.animationStart = dateProvider.date()
    }

    var scrollTarget: Int {
        let step = revision % 20
        let fraction = Double(step <= 10 ? step : 20 - step) / 10
        return items[Int(Double(items.count - 1) * fraction)].id
    }

    func runBenchmark() async -> Bool {
        guard !isRunning else { return false }
        let profiler = SentryThreadProfilerBenchmark()
        isRunning = true
        report = ""
        var measuring = false
        defer {
            if measuring { _ = metrics.finish() }
            stopActivity()
            isRunning = false
        }

        do {
            var baselineRuns: [BenchmarkResult] = []
            var profiledRuns: [BenchmarkResult] = []
            for trial in 1...Self.trialCount {
                for profiling in [false, true] {
                    let name = profiling ? "Profiler 50 ms" : "Baseline"
                    status = "Trial \(trial)/\(Self.trialCount), \(name): warming up for 2 seconds…"
                    print(status)
                    startActivity()
                    try await Task.sleep(for: .seconds(2))
                    if profiling {
                        await profiler.start()
                    }
                    status = "Trial \(trial)/\(Self.trialCount), \(name): measuring for 10 seconds…"
                    metrics.start()
                    measuring = true
                    try await Task.sleep(for: .seconds(10))
                    var result = metrics.finish()
                    measuring = false
                    stopActivity()
                    if profiling {
                        // Drain the sampler outside the measurement window, before restart.
                        result.profiler = ProfilerStatistics(await profiler.stop())
                        profiledRuns.append(result)
                    } else {
                        baselineRuns.append(result)
                        status = "Trial \(trial): baseline complete. Cooling down for 1 second…"
                        try await Task.sleep(for: .seconds(1))
                    }
                }
            }
            report = Self.format(baselineRuns, profiledRuns)
            print(report)
            let valid = profiledRuns.allSatisfy { $0.profiler.samples > 0 && $0.profiler.failures == 0 }
            status = valid ? "Comparison complete." : "Comparison invalid: profiler capture failed."
            return valid
        } catch {
            _ = await profiler.stop()
            status = "Benchmark cancelled."
            return false
        }
    }

    private func startActivity() {
        revision = 0
        tickCount = 0
        items = BenchmarkItem.catalog(revision: 0)
        animationStart = dateProvider.date()
        activityRunning = true
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.metrics.tick()
                self.tickCount += 1
                if self.tickCount.isMultiple(of: 15) {
                    self.revision += 1
                    self.items = BenchmarkItem.catalog(revision: self.revision)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        workTimer = timer
    }

    private func stopActivity() {
        workTimer?.invalidate()
        workTimer = nil
        activityRunning = false
    }

    private static func format(_ baselineRuns: [BenchmarkResult], _ profiledRuns: [BenchmarkResult]) -> String {
        let baseline = BenchmarkResult.aggregate(baselineRuns)
        let profiled = BenchmarkResult.aggregate(profiledRuns)
        func row(_ name: String, _ a: Double, _ b: Double) -> String {
            "\(name.padding(toLength: 25, withPad: " ", startingAt: 0)) \(number(a)) -> \(number(b)) (Δ \(number(b - a)))"
        }
        #if os(macOS)
        let platform = "macOS"
        #elseif targetEnvironment(simulator)
        let platform = "iPhone Simulator"
        #else
        let platform = "iPhone Physical Device"
        #endif
        let configuration = Bundle.main.object(forInfoDictionaryKey: "BenchmarkBuildConfiguration") as? String ?? "Unknown"
        let stats = profiled.profiler
        let trialChanges = zip(baselineRuns, profiledRuns).map { ($1.cpuPercent / $0.cpuPercent - 1) * 100 }
        let meanChange = trialChanges.reduce(0, +) / Double(trialCount)
        let variance = trialChanges.reduce(0) { $0 + pow($1 - meanChange, 2) } / Double(trialCount - 1)
        let sampleCounts = profiledRuns.map(\.profiler.samples)
        let trials = zip(baselineRuns, profiledRuns).enumerated().map { index, pair in
            "Trial \(index + 1): CPU \(number(pair.0.cpuPercent)) -> \(number(pair.1.cpuPercent)) %, samples \(pair.1.profiler.samples), capture failures \(pair.1.profiler.failures)"
        }.joined(separator: "\n")
        return """
        SENTRY THREAD INSPECTOR BENCHMARK (\(platform), \(configuration), baseline -> profiler)
        Sentry uses default options in both arms, except hang tracking and session replay are disabled.
        Trials: \(trialCount) baseline/profiled pairs; 2 s warm-up + 10 s measurement per arm.
        CPU is process user + system time, all threads. CPU %: 100 = one core.
        Rates use summed CPU/update counts divided by summed measurement time.
        \(row("Mean wall time (s)", baseline.wallSeconds / Double(trialCount), profiled.wallSeconds / Double(trialCount)))
        \(row("Mean CPU time (s)", baseline.cpuSeconds / Double(trialCount), profiled.cpuSeconds / Double(trialCount)))
        \(row("Process CPU (%)", baseline.cpuPercent, profiled.cpuPercent))
        Relative CPU change: \(number((profiled.cpuPercent / baseline.cpuPercent - 1) * 100)) %
        Paired CPU change: mean \(number(meanChange)) %, sample SD \(number(sqrt(variance))) %
        \(row("Main updates / s", baseline.updatesPerSecond, profiled.updatesPerSecond))
        \(row("Tick gap p95 (ms)", baseline.tickGapPercentile(0.95), profiled.tickGapPercentile(0.95)))
        \(row("Tick gap max (ms)", baseline.tickGapPercentile(1), profiled.tickGapPercentile(1)))
        Samples: \(stats.samples) total, \(number(Double(stats.samples) / Double(trialCount))) mean/trial, \(sampleCounts.min()!)-\(sampleCounts.max()!) range/trial
        Sampling cadence: 50 ms; approximately \(trialCount * 200) samples expected across all trials.
        Thread stacks: \(stats.threads), frames: \(stats.frames)
        \(captureReport(profiled))
        Tick gaps are main-timer callback intervals, not presented-frame times.
        Both arms use the same 60 Hz workload timer.
        Sampler startup/shutdown and printing are outside the measurement window.
        Percentiles pool the actual captured samples, rather than averaging trial percentiles.
        Five ordered pairs reduce noise but do not establish statistical significance.

        \(trials)
        """
    }

    private static func number(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private static func captureReport(_ result: BenchmarkResult) -> String {
        let stats = result.profiler
        let sampleCount = Double(max(1, stats.samples))
        func duration(_ seconds: Double) -> String {
            "\(number(seconds * 1_000_000)) µs (\(number(seconds * 1_000)) ms)"
        }
        return """
        Empty thread/stack captures: \(stats.failures)
        Only timings and aggregate counts are retained; stacks are discarded each sample.
        Inspector call total:  \(number(stats.captureDurations.reduce(0, +) * 1_000)) ms
        Inspector call mean:   \(duration(stats.captureDurations.reduce(0, +) / sampleCount))
        Inspector call median: \(duration(result.capturePercentile(0.5)))
        Inspector call p95:    \(duration(result.capturePercentile(0.95)))
        Inspector call p99:    \(duration(result.capturePercentile(0.99)))
        Inspector call max:    \(duration(result.capturePercentile(1)))
        Timings cover the full getCurrentThreadsWithStackTrace call, including stack construction.
        These are NOT thread suspension durations and are not directly comparable to the reference's pause windows.
        """
    }
}
