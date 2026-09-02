import Foundation

/// Asserts that the crash-time attachment payload directory was written correctly.
///
/// The scenario writes a synthetic screenshot via the KSCrash screenshot monitor. This asserter
/// verifies the on-disk evidence before the drain launch cleans it up:
///
/// - `<installDir>/SentryAttachments/<reportID_hex>/screenshot*.png` — a valid PNG file
/// - `<installDir>/Sidecars/SentryAttachments/<reportID_hex>.ksscr` — a valid Sentry marker
///
/// The asserter locates the payload directory by scanning `SentryAttachments/` for the most
/// recently modified subdirectory, so it does not need to know the report ID in advance.
enum CrashTimeAttachmentsAsserter {
    private static let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    // SATC magic + version byte 1
    private static let markerMagic: [UInt8] = [0x53, 0x41, 0x54, 0x43]
    private static let markerVersion: UInt8 = 1

    /// - Parameters:
    ///   - installDir: The KSCrash install directory (`<cacheDir>/KSCrash/<BundleName>`).
    ///   - platform: Human-readable platform label for assertion messages.
    static func assert(installDir: URL, platform: String) throws {
        let sentryAttachmentsDir = installDir.appendingPathComponent("SentryAttachments", isDirectory: true)
        let sidecarsDir = installDir
            .appendingPathComponent("Sidecars", isDirectory: true)
            .appendingPathComponent("SentryAttachments", isDirectory: true)

        let payloadDir = try findPayloadDirectory(under: sentryAttachmentsDir, platform: platform)
        let reportIDHex = payloadDir.lastPathComponent

        try assertScreenshotFile(in: payloadDir, platform: platform)
        try assertMarkerFile(in: sidecarsDir, reportIDHex: reportIDHex, platform: platform)

        log("✅ \(platform)/crash-time-attachments payload assertions passed (report \(reportIDHex)).")
    }

    // MARK: - Payload directory

    private static func findPayloadDirectory(under root: URL, platform: String) throws -> URL {
        let fm = FileManager.default
        if !fm.fileExists(atPath: root.path) {
            try fail("Expected SentryAttachments directory for \(platform)/crash-time-attachments: \(root.path)")
        }

        let contents = try fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        let dirs = try contents.filter { url in
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            return values.isDirectory == true
        }.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }

        guard let payloadDir = dirs.first else {
            try fail("Expected a per-report payload subdirectory under \(root.path) for \(platform)/crash-time-attachments")
        }
        return payloadDir
    }

    // MARK: - Screenshot

    private static func assertScreenshotFile(in payloadDir: URL, platform: String) throws {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(
            at: payloadDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        let screenshots = try contents.filter { url in
            let name = url.lastPathComponent
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            return values.isRegularFile == true
                && url.pathExtension == "png"
                && (name == "screenshot.png" || name.hasPrefix("screenshot-"))
        }

        try EventAssertions.assert(
            !screenshots.isEmpty,
            "Expected a screenshot PNG in \(payloadDir.path) for \(platform)/crash-time-attachments"
        )

        let screenshotURL = screenshots[0]
        let data = try Data(contentsOf: screenshotURL)
        try EventAssertions.assert(
            data.count >= pngSignature.count,
            "Screenshot file is too small to be a valid PNG for \(platform)/crash-time-attachments: \(screenshotURL.path)"
        )
        let headerBytes = [UInt8](data.prefix(pngSignature.count))
        try EventAssertions.assert(
            headerBytes == pngSignature,
            "Screenshot file does not have a PNG signature for \(platform)/crash-time-attachments: \(screenshotURL.path)"
        )
        log("  screenshot: \(screenshotURL.lastPathComponent) (\(data.count) bytes) ✓")
    }

    // MARK: - Marker

    private static func assertMarkerFile(in sidecarsDir: URL, reportIDHex: String,
                                         platform: String) throws {
        let markerURL = sidecarsDir.appendingPathComponent("\(reportIDHex).ksscr")
        try EventAssertions.assert(
            FileManager.default.fileExists(atPath: markerURL.path),
            "Expected sidecar marker at \(markerURL.path) for \(platform)/crash-time-attachments"
        )

        let data = try Data(contentsOf: markerURL)
        // Marker layout: 4 magic bytes + 1 version byte = 5 bytes minimum.
        try EventAssertions.assert(
            data.count >= markerMagic.count + 1,
            "Sidecar marker is too small for \(platform)/crash-time-attachments: \(markerURL.path)"
        )
        let magic = [UInt8](data.prefix(markerMagic.count))
        try EventAssertions.assert(
            magic == markerMagic,
            "Sidecar marker has unexpected magic bytes for \(platform)/crash-time-attachments: \(magic)"
        )
        let version = data[markerMagic.count]
        try EventAssertions.assert(
            version == markerVersion,
            "Sidecar marker has unexpected version \(version) for \(platform)/crash-time-attachments"
        )
        log("  sidecar marker: \(markerURL.lastPathComponent) ✓")
    }
}
