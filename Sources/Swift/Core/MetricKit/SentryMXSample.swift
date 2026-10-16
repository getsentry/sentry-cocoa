#if os(iOS) || os(macOS) || os(visionOS)
// A Sample is the standard data format for a flamegraph taken from https://github.com/brendangregg/FlameGraph
// It is less compact than Apple's MetricKit format, but contains the same data and is easier to work with
struct SentryMXSample {
    let count: Int
    let frames: [SentryMXSampleFrame]
}
#endif
