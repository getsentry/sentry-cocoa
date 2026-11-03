extension SentryRelayWireFormat {
    /// Namespace for profiling payloads and their shared wire-format components.
    ///
    /// @SeeAlso https://develop.sentry.dev/sdk/telemetry/profiles/
    enum Profiling {
        /// Namespace for the V2 profile chunk format used by continuous and UI profiling.
        ///
        /// @SeeAlso https://develop.sentry.dev/sdk/telemetry/profiles/#v2-sample-format-payload
        enum V2 {
            /// Native frame data shared by V2 profiles and flame graph attachments.
            /// Captured instruction addresses must be retained even when frames are symbolicated.
            ///
            /// @SeeAlso https://develop.sentry.dev/sdk/telemetry/profiles/#profile-data
            struct Frame: Encodable {
                /// Field names defined by the shared profiling frame schema.
                ///
                /// @SeeAlso https://develop.sentry.dev/sdk/telemetry/profiles/#profile-data
                enum CodingKeys: String, CodingKey {
                    case instructionAddress = "instruction_addr"
                    case package
                    case inApp = "in_app"
                }

                /// Captured native instruction address as a hexadecimal string prefixed with `0x`.
                let instructionAddress: String
                /// Binary or library containing the frame, when known.
                let package: String?
                /// Whether the frame belongs to application code, when known.
                let inApp: Bool?
            }
        }
    }
}
