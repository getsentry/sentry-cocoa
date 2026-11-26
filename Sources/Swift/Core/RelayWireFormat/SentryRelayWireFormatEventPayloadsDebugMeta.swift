extension SentryRelayWireFormat.EventPayloads {
    /// Debug metadata used to locate native debug files and map captured addresses to loaded images.
    /// Profiles and flame graph attachments reuse this event payload interface.
    ///
    /// @SeeAlso https://develop.sentry.dev/sdk/foundations/envelopes/event-payloads/debugmeta/
    struct DebugMeta: Encodable {
        /// Dynamic libraries and executables loaded in the process that produced the diagnostic.
        let images: [Image]

        /// Native debug image describing a binary and its placement in the captured process.
        /// Mach-O images require type `macho`, a debug identifier, and a loaded image address.
        ///
        /// @SeeAlso https://develop.sentry.dev/sdk/foundations/envelopes/event-payloads/debugmeta/#debug-images
        struct Image: Encodable {
            /// Debug image format, such as `macho` for native Apple binaries.
            let type: String?
            /// Binary debug identifier. Mach-O images use the UUID from the `LC_UUID` load command.
            let debugID: String?
            /// Name or absolute path of the binary, when available.
            let codeFile: String?
            /// Loaded image address as a hexadecimal string prefixed with `0x`.
            let imageAddress: String?
            /// Image size in virtual memory. When absent, the server infers its extent from other images.
            let imageSize: UInt64?
            /// Preferred load address declared in the binary's headers, when available.
            let imageVmAddress: String?

            /// Field names defined by the native debug image schema.
            ///
            /// @SeeAlso https://develop.sentry.dev/sdk/foundations/envelopes/event-payloads/debugmeta/#mach-o-images
            enum CodingKeys: String, CodingKey {
                case type
                case debugID = "debug_id"
                case codeFile = "code_file"
                case imageAddress = "image_addr"
                case imageSize = "image_size"
                case imageVmAddress = "image_vmaddr"
            }
        }
    }
}
