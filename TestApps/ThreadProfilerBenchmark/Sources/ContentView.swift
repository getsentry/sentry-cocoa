import Foundation
import SwiftUI

@MainActor
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var session = BenchmarkSession()
    @State private var benchmarkTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Sentry Thread Inspector Benchmark")
                .font(.largeTitle.bold())

            Text("Five baseline/profiled pairs with Sentry enabled and the same animated, scrolling workload. Hang tracking and replay are disabled. Each arm warms up for 2 seconds and measures for 10 seconds. The SDK thread inspector samples all threads every 50 ms. Allow about two minutes.")
                .foregroundStyle(.secondary)

            BenchmarkScene(session: session)
                .frame(height: 360)
                .frame(maxWidth: .infinity)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
                .clipShape(RoundedRectangle(cornerRadius: 16))

            HStack {
                Button(benchmarkTask == nil ? "Run 5-pair benchmark" : "Cancel") {
                    if let benchmarkTask {
                        benchmarkTask.cancel()
                    } else {
                        startBenchmark()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            Text(session.status)
                .font(.callout.monospacedDigit())
                .accessibilityIdentifier("benchmarkStatus")

            if !session.report.isEmpty {
                ScrollView([.horizontal, .vertical]) {
                    Text(session.report)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                .frame(height: 220)
            }

            Text("Use a Release build on the same device. This reports process CPU cost and main-thread timing, not authoritative frame-presentation hitches.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: 800)
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("--benchmark"), benchmarkTask == nil {
                startBenchmark()
            }
        }
        .onDisappear { benchmarkTask?.cancel() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { benchmarkTask?.cancel() }
        }
    }

    private func startBenchmark() {
        benchmarkTask = Task { [self] in
            let success = await session.runBenchmark()
            benchmarkTask = nil
            if ProcessInfo.processInfo.arguments.contains("--benchmark") {
                print("BENCHMARK_STATUS: \(success ? "PASS" : "FAIL")")
                fflush(stdout)
                exit(success ? 0 : 1)
            }
        }
    }
}

private struct BenchmarkScene: View {
    let session: BenchmarkSession

    var body: some View {
        if session.activityRunning {
            VStack(spacing: 0) {
                DrawingWorkload(start: session.animationStart)
                    .frame(height: 150)
                CatalogWorkload(session: session)
            }
        } else {
            placeholder("Ready to profile", symbol: "waveform.path", detail: "Each run resets the workload")
        }
    }

    private func placeholder(_ title: String, symbol: String, detail: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.largeTitle)
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct DrawingWorkload: View {
    let start: Date

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                for index in 0..<64 {
                    let phase = Double(index) * 0.7
                    let x = (0.5 + 0.44 * sin(time * 0.8 + phase)) * size.width
                    let y = (0.5 + 0.40 * cos(time * 1.1 + phase * 1.3)) * size.height
                    let rect = CGRect(x: x - 12, y: y - 12, width: 24, height: 24)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 6),
                        with: .color(Color(hue: Double(index) / 64, saturation: 0.7, brightness: 0.95))
                    )
                }
            }
        }
        .background(.black)
        .accessibilityLabel("Continuously redrawn moving shapes")
    }
}

private struct CatalogWorkload: View {
    let session: BenchmarkSession

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(session.items) { item in
                        HStack(spacing: 16) {
                            Image(systemName: "chart.bar.fill")
                                .foregroundStyle(.indigo)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.title)
                                    .font(.headline)
                                ProgressView(value: Double(item.score), total: 100)
                            }
                            Text("\(item.score)")
                                .monospacedDigit()
                                .frame(width: 32)
                        }
                        .padding()
                        .background(.background, in: RoundedRectangle(cornerRadius: 12))
                        .id(item.id)
                    }
                }
                .padding()
            }
            .onAppear { proxy.scrollTo(session.scrollTarget, anchor: .top) }
            .onChange(of: session.revision) {
                withAnimation(.linear(duration: 0.25)) {
                    proxy.scrollTo(session.scrollTarget, anchor: .top)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
