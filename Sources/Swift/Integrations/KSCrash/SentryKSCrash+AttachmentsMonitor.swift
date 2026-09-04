#if SDK_V10
internal import _SentryPrivate
internal import KSCrashRecording
internal import KSCrashRecordingCore
import Foundation

// MARK: - Monitor

extension SentryKSCrash {
    /// KSCrash plugin that captures crash-time attachments after the JSON report is on disk
    /// and stitches payload paths into the report on the next launch.
    ///
    /// Layout:
    /// ```
    /// <installDir>/
    ///   Sidecars/SentryAttachments/<reportID>.ksscr   // stitch gate, not the payload
    ///   SentryAttachments/<reportID>/screenshot.png   // envelope files
    /// ```
    ///
    /// The sidecar path is one file. KSCrash only calls `createStitchedReport` when
    /// that `.ksscr` exists, and only deletes that file when the report is deleted.
    /// Attachments are arbitrary files, so they cannot live in the sidecar without unpacking
    /// at stitch time. They live in a Sentry-owned sibling directory. After the crash report
    /// is captured into an envelope, Sentry deletes that payload directory; KSCrash will not.
    ///
    /// Monitor ID is `SentryAttachments` so KSCrash looks up this plugin's marker.
    final class AttachmentsMonitor: NSObject, MonitorPlugin, @unchecked Sendable {

        typealias Context = UnsafeMutableRawPointer?
        typealias InitCallback = @convention(c) (UnsafeMutablePointer<KSCrash_ExceptionHandlerCallbacks>?, Context) -> Void
        typealias MonitorIDCallback = @convention(c) (Context) -> UnsafePointer<CChar>?
        typealias MonitorFlagsCallback = @convention(c) (Context) -> KSCrashMonitorFlag
        typealias SetEnabledCallback = @convention(c) (Bool, Context) -> Void
        typealias IsEnabledCallback = @convention(c) (Context) -> Bool
        typealias AddContextualInfoCallback = @convention(c) (UnsafeMutablePointer<KSCrash_MonitorContext>?, Context) -> Void
        typealias NotifyCallback = @convention(c) (Context) -> Void
        typealias StitchCallback = @convention(c) (
            CFDictionary?, UnsafePointer<CChar>?, KSCrashSidecarScope, Context
        ) -> Unmanaged<CFDictionary>?
        typealias CrashTimeWriter = (URL) -> Void

        static let attachmentsReportKey = "attachments"

        /// Commit token written to the KSCrash sidecar path after payload files exist.
        ///
        /// KSCrash's stitch gate is existence of this `.ksscr` file, so this write cannot
        /// be replaced by moving attachments under `Sidecars/`. Written last: no marker
        /// means stitch never runs. Magic (`0xDEADBEEF`) and version reject truncated or
        /// foreign files; crash-time I/O can die after creating the path.
        struct Marker {
            static let version: UInt8 = 1
            static let magic: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF] // 0xDEADBEEF

            static func write(to sidecarPath: URL) {
                var bytes = magic
                bytes.append(version)
                try? Data(bytes).write(to: sidecarPath, options: .atomic)
            }

            static func isValid(at sidecarPath: URL) -> Bool {
                guard let data = try? Data(contentsOf: sidecarPath),
                      data.count >= magic.count + 1
                else {
                    return false
                }
                let header = [UInt8](data.prefix(magic.count))
                guard header == magic else { return false }
                return data[magic.count] == version
            }
        }

        /// Payload lives in a Sentry-owned sibling of `Sidecars/`, not under it.
        /// KSCrash cleanup only removes `<reportID>.ksscr`; Sentry removes this directory
        /// after the report is captured into an envelope.
        struct Layout {
            static let monitorID = String(cString: sentrykscrash_attachmentsMonitorID)
            static let payloadDirectoryName = "SentryAttachments"
            static let sidecarsDirectoryName = "Sidecars"

            /// `.../Sidecars/SentryAttachments/<reportID>.ksscr` → `.../SentryAttachments/<reportID>/`
            static func payloadDirectory(from sidecarPath: URL) -> URL? {
                let monitorDirectory = sidecarPath.deletingLastPathComponent()
                guard monitorDirectory.lastPathComponent == monitorID else { return nil }

                let sidecarsDirectory = monitorDirectory.deletingLastPathComponent()
                guard sidecarsDirectory.lastPathComponent == sidecarsDirectoryName else { return nil }

                let reportIDHex = sidecarPath.deletingPathExtension().lastPathComponent
                guard reportIDHex.count == 16 else { return nil }

                return sidecarsDirectory
                    .deletingLastPathComponent()
                    .appendingPathComponent(payloadDirectoryName, isDirectory: true)
                    .appendingPathComponent(reportIDHex, isDirectory: true)
            }

            /// Deletes owned payload directories after their files have been copied into an
            /// envelope. Ignores paths that are not `.../SentryAttachments/<16-hex-report-id>/...`.
            static func removeConsumedPayloadDirectories(forAttachmentPaths paths: [String]) {
                var directories = Set<URL>()
                for path in paths {
                    let directory = URL(fileURLWithPath: path).deletingLastPathComponent()
                    let reportIDHex = directory.lastPathComponent
                    guard reportIDHex.count == 16,
                          reportIDHex.allSatisfy(\.isHexDigit),
                          directory.deletingLastPathComponent().lastPathComponent == payloadDirectoryName
                    else {
                        continue
                    }
                    directories.insert(directory)
                }
                for directory in directories {
                    try? FileManager.default.removeItem(at: directory)
                }
            }
        }

        enum ScreenshotFiles {
            static let primaryName = "screenshot.png"
            static let numberedPrefix = "screenshot-"
            static let fileExtension = "png"
            static let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

            static func paths(in payloadDirectory: URL) -> [URL] {
                guard let contents = try? FileManager.default.contentsOfDirectory(
                    at: payloadDirectory,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) else {
                    return []
                }

                var ranked: [(rank: Int, url: URL)] = []
                for url in contents {
                    let isFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
                    guard isFile, let rank = rank(for: url.lastPathComponent) else { continue }
                    guard hasPNGSignature(at: url) else { continue }
                    ranked.append((rank, url))
                }
                return ranked.sorted { lhs, rhs in
                    if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
                    return lhs.url.path < rhs.url.path
                }.map(\.url)
            }

            private static func rank(for fileName: String) -> Int? {
                if fileName == primaryName {
                    return 1
                }
                let suffix = ".\(fileExtension)"
                guard fileName.hasPrefix(numberedPrefix), fileName.hasSuffix(suffix) else {
                    return nil
                }
                let digits = fileName.dropFirst(numberedPrefix.count).dropLast(suffix.count)
                guard let value = Int(digits), value >= 2 else { return nil }
                return value
            }

            private static func hasPNGSignature(at url: URL) -> Bool {
                guard let data = try? Data(contentsOf: url),
                      data.count >= pngSignature.count
                else {
                    return false
                }
                return [UInt8](data.prefix(pngSignature.count)) == pngSignature
            }
        }

        // MARK: - State

        struct MonitorState {
            var enabled: Bool = false
            var callbacks: KSCrash_ExceptionHandlerCallbacks?
        }

        private let state = SentryMutex(MonitorState())

        private let _monitorId: UnsafeMutablePointer<CChar> = strdup(sentrykscrash_attachmentsMonitorID)

        /// Writes screenshot files into the per-report payload directory. Invoked on the crash
        /// thread after the JSON report is on disk; must not hop to the main queue.
        var screenshotProvider: CrashTimeWriter?

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

        // MARK: - Callbacks
        private static let apiInitCallback: InitCallback = { callbacks, context in
            SentryKSCrash.AttachmentsMonitor.from(context)?.callbacks = callbacks?.pointee
        }

        private static let monitorIDCallback: MonitorIDCallback = { context in
            guard let monitor = SentryKSCrash.AttachmentsMonitor.from(context) else { return nil }
            return UnsafePointer(monitor._monitorId)
        }

        private static let monitorFlagsCallback: MonitorFlagsCallback = { _ in KSCrashMonitorFlagPlugin }

        private static let setEnabledCallback: SetEnabledCallback = { isEnabled, context in
            SentryKSCrash.AttachmentsMonitor.from(context)?.enabled = isEnabled
        }

        private static let isEnabledCallback: IsEnabledCallback = { context in
            SentryKSCrash.AttachmentsMonitor.from(context)?.enabled ?? false
        }

        private static let addContextualInfoCallback: AddContextualInfoCallback = { _, _ in }

        private static let notifyPostSystemEnableCallback: NotifyCallback = { _ in }

        private static let createStitchedReportCallback: StitchCallback = { reportDict, sidecarPath, scope, context in
            guard let reportDict else { return nil }
            guard let monitor = SentryKSCrash.AttachmentsMonitor.from(context) else {
                return Unmanaged.passRetained(reportDict)
            }
            return monitor.stitchedReport(
                reportDict: reportDict,
                sidecarPath: sidecarPath,
                scope: scope
            )
        }
    }
}

// MARK: - API Initialisation
extension SentryKSCrash.AttachmentsMonitor {
    func initAPI() {
        api.initialize(
            to: KSCrashMonitorAPI(
                context: nil,
                init: Self.apiInitCallback,
                monitorId: Self.monitorIDCallback,
                monitorFlags: Self.monitorFlagsCallback,
                setEnabled: Self.setEnabledCallback,
                isEnabled: Self.isEnabledCallback,
                addContextualInfoToEvent: Self.addContextualInfoCallback,
                notifyPostMonitorsEnabled: nil,
                notifyPostSystemEnable: Self.notifyPostSystemEnableCallback,
                writeInReportSection: nil,
                createStitchedReport: Self.createStitchedReportCallback
            )
        )
        api.pointee.context = Unmanaged.passUnretained(self).toOpaque()
    }

    static func from(_ context: Context) -> SentryKSCrash.AttachmentsMonitor? {
        guard let context else { return nil }
        return Unmanaged<SentryKSCrash.AttachmentsMonitor>.fromOpaque(context).takeUnretainedValue()
    }
}

// MARK: - Locking Helpers
extension SentryKSCrash.AttachmentsMonitor {
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
extension SentryKSCrash.AttachmentsMonitor {
    func handleDidWriteReport(reportID: Int64) {
        guard enabled else {
            SentrySDKLog.debug("Not running handleDidWriteReport for reportID: \(reportID) because monitor is not enabled")
            return
        }
        guard reportID > 0 else {
            SentrySDKLog.debug("Not running handleDidWriteReport for reportID: \(reportID) because reportID is not valid")
            return
        }
        guard let screenshotProvider else {
            SentrySDKLog.debug("Not running handleDidWriteReport for reportID: \(reportID) because screenshotProvider was not set")
            return
        }
        guard
            let sidecarPath = sidecarPath(for: reportID),
            let payloadDirectory = Layout.payloadDirectory(from: sidecarPath)
        else {
            SentrySDKLog.debug("Failed to get report sidecar or payload path for reportID: \(reportID)")
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: payloadDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            SentrySDKLog.debug("Failed to create directory: \(payloadDirectory)")
            return
        }

        screenshotProvider(payloadDirectory)

        let screenshots = ScreenshotFiles.paths(in: payloadDirectory)
        guard !screenshots.isEmpty else {
            try? FileManager.default.removeItem(at: payloadDirectory)
            return
        }

        // Last on purpose: without this file KSCrash will not stitch the report.
        Marker.write(to: sidecarPath)
    }

    func sidecarPath(for reportID: Int64) -> URL? {
        guard let getReportSidecarPath = callbacks?.getReportSidecarPath else { return nil }

        var pathBuffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        let copied = pathBuffer.withUnsafeMutableBufferPointer { buffer -> Bool in
            guard let base = buffer.baseAddress else { return false }
            return getReportSidecarPath(self._monitorId, reportID, base, buffer.count)
        }

        guard copied else {
            SentrySDKLog.debug("Failed to get report sidecar path for reportID: \(reportID)")
            return nil
        }

        return URL(fileURLWithPath: String(cString: pathBuffer))
    }
}

// MARK: - Next-launch stitch
extension SentryKSCrash.AttachmentsMonitor {
    /// Injects sibling payload paths under `"attachments"`. Sidecar bytes are only the marker.
    func stitchedReport(
        reportDict: CFDictionary,
        sidecarPath: UnsafePointer<CChar>?,
        scope: KSCrashSidecarScope
    ) -> Unmanaged<CFDictionary> {
        guard scope == KSCrashSidecarScopeReport, let sidecarPath else {
            return Unmanaged.passRetained(reportDict)
        }

        let sidecar = URL(fileURLWithPath: String(cString: sidecarPath))
        guard Marker.isValid(at: sidecar),
              let payloadDirectory = Layout.payloadDirectory(from: sidecar)
        else {
            return Unmanaged.passRetained(reportDict)
        }

        let incoming = ScreenshotFiles.paths(in: payloadDirectory).map(\.path)
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

@_cdecl("sentrykscrash_attachments_handleDidWriteReport")
func sentrykscrash_attachments_handleDidWriteReport(_ context: UnsafeMutableRawPointer?, _ reportID: Int64) {
    SentryKSCrash.AttachmentsMonitor.from(context)?.handleDidWriteReport(reportID: reportID)
}
#endif
