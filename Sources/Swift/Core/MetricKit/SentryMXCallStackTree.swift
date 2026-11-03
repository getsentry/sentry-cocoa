#if os(iOS) || os(macOS) || os(visionOS)
/// A Data object containing the JSON representation of the stack tree returned from ``MXCallStackTree.jsonRepresentation()``
///
/// - SeeAlso: JSON specification of ``MXCallStackTree`` can be found   [here](https://developer.apple.com/documentation/metrickit/mxcallstacktree/3552293-jsonrepresentation)
struct SentryMXCallStackTree: Decodable {

    /// An array of call stacks for a process or thread.
    let callStacks: [SentryMXCallStack]

    /// A Boolean specifying whether the stack trace is for a single process thread or for all process threads.
    let callStackPerThread: Bool
}
#endif
