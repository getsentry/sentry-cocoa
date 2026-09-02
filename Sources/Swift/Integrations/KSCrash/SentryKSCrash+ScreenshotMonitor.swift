#if SDK_V10
internal import KSCrashRecording
internal import KSCrashRecordingCore
import Foundation

// MARK: - Monitor

extension SentryKSCrash {
    /// KSCrash plugin that captures a crash-time screenshot after the JSON report is on disk
    /// and stitches the payload path into the report on the next launch.
    ///
    /// Monitor ID is `SentryAttachments` so KSCrash stores the marker at
    /// `Sidecars/SentryAttachments/<reportID>.ksscr` and stitch can find it.
    final class ScreenshotMonitor: NSObject, MonitorPlugin, @unchecked Sendable {

        static let monitorID = "SentryAttachments"
        static let attachmentsReportKey = "attachments"
        static let payloadDirectoryName = "SentryAttachments"
        static let sidecarsDirectoryName = "Sidecars"
        static let screenshotFileName = "screenshot.png"
        static let screenshotFilePrefix = "screenshot-"
        static let screenshotFileExtension = "png"
        static let markerVersion: UInt8 = 1
        static let markerMagic: [UInt8] = [0x53, 0x41, 0x54, 0x43] // SATC
        static let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

        // MARK: - State

        struct MonitorState {
            var enabled: Bool = false
            var callbacks: KSCrash_ExceptionHandlerCallbacks?
        }

        private let state = SentryMutex(MonitorState())

        private let _monitorId: UnsafeMutablePointer<CChar> = strdup(ScreenshotMonitor.monitorID)

        /// Writes screenshot files into the per-report payload directory. Invoked on the crash
        /// thread after the JSON report is on disk; must not hop to the main queue.
        var screenshotProvider: ((String) -> Void)?

        nonisolated(unsafe) static weak var active: ScreenshotMonitor?

        let cDidWriteHandler: @convention(c) (Int64) -> Void = { reportID in
            active?.handleDidWriteReport(reportID: reportID)
        }

        // MARK: - MonitorPlugin

        let api: UnsafeMutablePointer<KSCrashMonitorAPI>

        // MARK: - Lifecycle

        override init() {
            self.api = UnsafeMutablePointer<KSCrashMonitorAPI>.allocate(capacity: 1)
            super.init()
            initAPI()
        }

        deinit {
            api.deinitialize(count: 1)
            api.deallocate()
            free(_monitorId)
        }
    }
}

// MARK: - API Initialisation

extension SentryKSCrash.ScreenshotMonitor {
    func initAPI() {
        api.initialize(
            to: KSCrashMonitorAPI(
                context: nil,
                init: { callbacks, context in
                    SentryKSCrash.ScreenshotMonitor.from(context)?.callbacks = callbacks?.pointee
                },
                monitorId: { context in
                    guard let monitor = SentryKSCrash.ScreenshotMonitor.from(context) else { return nil }
                    return UnsafePointer(monitor._monitorId)
                },
                monitorFlags: { _ in KSCrashMonitorFlagPlugin },
                setEnabled: { isEnabled, context in
                    SentryKSCrash.ScreenshotMonitor.from(context)?.enabled = isEnabled
                },
                isEnabled: { context in
                    SentryKSCrash.ScreenshotMonitor.from(context)?.enabled ?? false
                },
                addContextualInfoToEvent: { _, _ in },
                notifyPostMonitorsEnabled: nil,
                notifyPostSystemEnable: { _ in },
                writeInReportSection: nil,
                createStitchedReport: { reportDict, sidecarPath, scope, context in
                    guard let reportDict else { return nil }
                    guard let monitor = SentryKSCrash.ScreenshotMonitor.from(context) else {
                        return Unmanaged.passRetained(reportDict)
                    }
                    return monitor.stitchedReport(
                        reportDict: reportDict,
                        sidecarPath: sidecarPath,
                        scope: scope
                    )
                }
            )
        )
        api.pointee.context = Unmanaged.passUnretained(self).toOpaque()
    }

    static func from(_ context: UnsafeMutableRawPointer?) -> SentryKSCrash.ScreenshotMonitor? {
        guard let context else { return nil }
        return Unmanaged<SentryKSCrash.ScreenshotMonitor>.fromOpaque(context).takeUnretainedValue()
    }
}

// MARK: - Locking Helpers
extension SentryKSCrash.ScreenshotMonitor {
    var enabled: Bool {
        get { state.withLock { $0.enabled } }
        set { state.withLock { $0.enabled = newValue } }
    }

    var callbacks: KSCrash_ExceptionHandlerCallbacks? {
        get { state.withLock { $0.callbacks } }
        set { state.withLock { $0.callbacks = newValue } }
    }
}

// MARK: - Crash-time capture

extension SentryKSCrash.ScreenshotMonitor {
    /// Captures the screenshot into the per-report payload directory and writes the KSCrash
    /// marker sidecar. Called from `didWriteReport` after the JSON report is on disk.
    func handleDidWriteReport(reportID: Int64) {
        guard enabled, reportID > 0, screenshotProvider != nil else { return }
        guard let sidecarPath = reportSidecarPath(reportID: reportID) else { return }
        guard let payloadDirectory = payloadDirectory(fromSidecarPath: sidecarPath) else { return }

        do {
            try FileManager.default.createDirectory(
                atPath: payloadDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            return
        }

        screenshotProvider?(payloadDirectory)

        let screenshots = screenshotPaths(in: payloadDirectory)
        guard !screenshots.isEmpty else {
            try? FileManager.default.removeItem(atPath: payloadDirectory)
            return
        }

        writeMarker(to: sidecarPath)
    }
}

// MARK: - Next-launch stitch

extension SentryKSCrash.ScreenshotMonitor {
    func stitchedReport(
        reportDict: CFDictionary,
        sidecarPath: UnsafePointer<CChar>?,
        scope: KSCrashSidecarScope
    ) -> Unmanaged<CFDictionary> {
        guard scope == KSCrashSidecarScopeReport, let sidecarPath else {
            return Unmanaged.passRetained(reportDict)
        }

        let sidecar = String(cString: sidecarPath)
        guard isValidMarker(at: sidecar),
              let payloadDirectory = payloadDirectory(fromSidecarPath: sidecar)
        else {
            return Unmanaged.passRetained(reportDict)
        }

        let incoming = screenshotPaths(in: payloadDirectory)
        guard !incoming.isEmpty else {
            return Unmanaged.passRetained(reportDict)
        }

        let original = reportDict as NSDictionary
        let existing = (original[Self.attachmentsReportKey] as? [String]) ?? []
        var merged = existing
        var seen = Set(existing)
        for path in incoming where !seen.contains(path) {
            merged.append(path)
            seen.insert(path)
        }
        guard merged != existing else {
            return Unmanaged.passRetained(reportDict)
        }

        let stitched = NSMutableDictionary(dictionary: original)
        stitched[Self.attachmentsReportKey] = merged
        return Unmanaged.passRetained(stitched as CFDictionary)
    }
}

// MARK: - Paths and marker

extension SentryKSCrash.ScreenshotMonitor {
    func reportSidecarPath(reportID: Int64) -> String? {
        guard let getReportSidecarPath = callbacks?.getReportSidecarPath else { return nil }

        var pathBuffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        let copied = pathBuffer.withUnsafeMutableBufferPointer { buffer -> Bool in
            guard let base = buffer.baseAddress else { return false }
            return getReportSidecarPath(self._monitorId, reportID, base, buffer.count)
        }
        guard copied else { return nil }
        return String(cString: pathBuffer)
    }

    func payloadDirectory(fromSidecarPath sidecarPath: String) -> String? {
        let sidecarURL = URL(fileURLWithPath: sidecarPath)
        // .../Sidecars/SentryAttachments/<reportID>.ksscr
        let monitorDirectory = sidecarURL.deletingLastPathComponent()
        guard monitorDirectory.lastPathComponent == Self.monitorID else { return nil }

        let sidecarsDirectory = monitorDirectory.deletingLastPathComponent()
        guard sidecarsDirectory.lastPathComponent == Self.sidecarsDirectoryName else { return nil }

        let reportIDHex = sidecarURL.deletingPathExtension().lastPathComponent
        guard reportIDHex.count == 16 else { return nil }

        return sidecarsDirectory
            .deletingLastPathComponent()
            .appendingPathComponent(Self.payloadDirectoryName, isDirectory: true)
            .appendingPathComponent(reportIDHex, isDirectory: true)
            .path
    }

    func writeMarker(to sidecarPath: String) {
        var bytes = Self.markerMagic
        bytes.append(Self.markerVersion)
        try? Data(bytes).write(to: URL(fileURLWithPath: sidecarPath), options: .atomic)
    }

    func isValidMarker(at sidecarPath: String) -> Bool {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: sidecarPath)),
              data.count >= Self.markerMagic.count + 1
        else {
            return false
        }
        let magic = [UInt8](data.prefix(Self.markerMagic.count))
        guard magic == Self.markerMagic else { return false }
        return data[Self.markerMagic.count] == Self.markerVersion
    }

    func screenshotPaths(in payloadDirectory: String) -> [String] {
        let directoryURL = URL(fileURLWithPath: payloadDirectory, isDirectory: true)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var ranked: [(rank: Int, path: String)] = []
        for url in contents {
            let isFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
            guard isFile, let rank = screenshotRank(for: url.lastPathComponent) else { continue }
            guard hasPNGSignature(at: url) else { continue }
            ranked.append((rank, url.path))
        }
        return ranked.sorted { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            return lhs.path < rhs.path
        }.map(\.path)
    }

    private func screenshotRank(for fileName: String) -> Int? {
        if fileName == Self.screenshotFileName {
            return 1
        }
        guard fileName.hasPrefix(Self.screenshotFilePrefix),
              fileName.hasSuffix(".\(Self.screenshotFileExtension)")
        else {
            return nil
        }
        let start = Self.screenshotFilePrefix.endIndex
        let end = fileName.index(fileName.endIndex, offsetBy: -(Self.screenshotFileExtension.count + 1))
        guard start < end else { return nil }
        let digits = fileName[start..<end]
        guard let value = Int(digits), value >= 2 else { return nil }
        return value
    }

    private func hasPNGSignature(at url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url),
              data.count >= Self.pngSignature.count
        else {
            return false
        }
        return [UInt8](data.prefix(Self.pngSignature.count)) == Self.pngSignature
    }
}
#endif
