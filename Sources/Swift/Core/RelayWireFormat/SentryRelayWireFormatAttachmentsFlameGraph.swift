extension SentryRelayWireFormat.Attachments {
    /// Version 1 of an aggregated call-tree attachment using shared profiling frames and debug metadata.
    /// Send as `flamegraph.json` with content type `application/json` and attachment type `event.flamegraph`
    /// in the associated event's envelope. The serialized payload must not exceed 10 MiB.
    ///
    /// @SeeAlso https://develop.sentry.dev/sdk/telemetry/attachments/#flame-graph-payload
    struct FlameGraph: Encodable {
        typealias FrameIndex = TypedIndex<SentryRelayWireFormat.Profiling.V2.Frame, Int>

        /// Wire-format version used by consumers to interpret the payload.
        let version = "1"
        /// Default Sentry platform for the captured native Apple frames.
        let platform = "cocoa"
        /// Non-empty shared frame table. Frame indices have no stack ordering.
        let frames: [SentryRelayWireFormat.Profiling.V2.Frame]
        /// Non-empty flat table of frame occurrences referenced by roots and children.
        let nodes: [Node]
        /// Non-empty collection of independent call trees.
        let trees: [Tree]
        /// Symbolication inputs from the process that produced the diagnostic, not the uploading process.
        let debugMeta: SentryRelayWireFormat.EventPayloads.DebugMeta

        /// Field names defined by the flame graph payload schema.
        ///
        /// @SeeAlso https://develop.sentry.dev/sdk/telemetry/attachments/#flame-graph-payload
        enum CodingKeys: String, CodingKey {
            case version, platform, frames, nodes, trees
            case debugMeta = "debug_meta"
        }

        /// Independent sample population preserving a source call stack or thread.
        /// Its total sample count is the sum of its root counts. Paths run from caller to callee.
        ///
        /// @SeeAlso https://develop.sentry.dev/sdk/telemetry/attachments/#flame-graph-trees
        struct Tree: Encodable {
            /// Non-empty indices into the node table for the oldest retained callers.
            let roots: [Node.Index]
            /// Whether the diagnostic source attributes the reported issue to this tree's thread.
            /// Omitted when the attribution is unknown.
            let threadAttributed: Bool?

            /// Field names defined by the flame graph tree schema.
            ///
            /// @SeeAlso https://develop.sentry.dev/sdk/telemetry/attachments/#flame-graph-trees
            enum CodingKeys: String, CodingKey {
                case roots
                case threadAttributed = "thread_attributed"
            }
        }

        /// One frame occurrence in an aggregated call path, including samples ending at that occurrence.
        /// The sum of direct children's counts must not exceed this node's count.
        ///
        /// @SeeAlso https://develop.sentry.dev/sdk/telemetry/attachments/#flame-graph-nodes
        struct Node: Encodable {
            typealias Index = TypedIndex<Self, Int>

            /// Zero-based index into the attachment's shared frame table.
            let frameID: FrameIndex
            /// Positive inclusive sample count, no greater than `9007199254740991`.
            let sampleCount: Int
            /// Indices into the node table for direct callees. Omission is equivalent to an empty array.
            let children: [Index]?

            /// Field names defined by the flame graph node schema.
            ///
            /// @SeeAlso https://develop.sentry.dev/sdk/telemetry/attachments/#flame-graph-nodes
            enum CodingKeys: String, CodingKey {
                case frameID = "frame_id"
                case sampleCount = "sample_count"
                case children
            }
        }
    }
}
