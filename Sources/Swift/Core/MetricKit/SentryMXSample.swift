#if os(iOS) || os(macOS) || os(visionOS)
// A sample represents the flamegraph data format described at https://github.com/brendangregg/FlameGraph.
// This is a format reference only. No code from the FlameGraph project is used here.
// It is less compact than Apple's MetricKit format, but contains the same data and is easier to work with
struct SentryMXSample {
    let count: Int
    let frames: [SentryMXSampleFrame]
}
#endif
