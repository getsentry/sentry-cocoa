#if SDK_V10
internal import _SentryPrivate
internal import KSCrashRecording
internal import KSCrashRecordingCore
import Foundation

// MARK: - Monitor

extension SentryKSCrash {
    /// KSCrash plugin for crash attachments.
    ///
    /// Owns setup (enable, sidecar path, screenshot writer callback) and
    /// next-launch stitch. Crash-time capture is C (`sentrykscrash_attachments_capture`).
    ///
    /// On-disk layout:
    /// ```
    /// <installDir>/
    ///   Sidecars/SentryAttachments/<reportID>.ksscr   // stitch gate, not the payload
    ///   SentryAttachments/<reportID>/screenshot.png   // envelope files
    /// ```
    ///
    /// The sidecar path is one file. KSCrash only calls `createStitchedReport` when
    /// that `.ksscr` exists, and only deletes that file when the report is deleted.
    /// Attachments are arbitrary files, so they cannot live in the sidecar without unpacking
    /// at stitch time. They live in a Sentry-owned sibling directory. KSCrash deletes the report
    /// and `.ksscr` marker; Sentry sweeps leftover payload directories after delivery.
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

        static let attachmentsReportKey = "attachments"

        /// Commit token written to the KSCrash sidecar path after payload files exist.
        ///
        /// Presence of this file is evidence that attachments were correctly written to disk
        /// and without this file KSCrash will not call `createStitchedReport`.
        /// Crash-time I/O can die after creating the path, so write a known marker
        struct Marker {
            static let version: UInt8 = 1
            static let magic: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]

            private static let header: Data = {
                var bytes = Data(capacity: magic.count + 1)
                bytes.append(contentsOf: magic)
                bytes.append(version)
                return bytes
            }()

            static func isValid(at sidecarPath: URL) -> Bool {
                (try? Data(contentsOf: sidecarPath)) == header
            }
        }

        struct Layout {
            static let monitorID = String(cString: sentrykscrash_attachmentsMonitorID)
            static let payloadDirectoryName = "SentryAttachments"
            static let sidecarsDirectoryName = "Sidecars"

            /// `.../Sidecars/SentryAttachments/<reportID>.ksscr` → `.../SentryAttachments/<reportID>/`
            static func payloadDirectory(from sidecarPath: URL) -> URL? {
                let monitorDirectory = sidecarPath.deletingLastPathComponent()
                guard monitorDirectory.lastPathComponent == monitorID else {
                    SentrySDKLog.debug(
                        "Not deriving payload directory because monitor directory is \(monitorDirectory.lastPathComponent), expected \(monitorID)"
                    )
                    return nil
                }

                let sidecarsDirectory = monitorDirectory.deletingLastPathComponent()
                guard sidecarsDirectory.lastPathComponent == sidecarsDirectoryName else {
                    SentrySDKLog.debug(
                        "Not deriving payload directory because sidecars directory is \(sidecarsDirectory.lastPathComponent), expected \(sidecarsDirectoryName)"
                    )
                    return nil
                }

                let reportIDHex = sidecarPath.deletingPathExtension().lastPathComponent
                guard reportIDHex.count == 16 else {
                    SentrySDKLog.debug(
                        "Not deriving payload directory because report id '\(reportIDHex)' is not 16 hex characters"
                    )
                    return nil
                }

                return sidecarsDirectory
                    .deletingLastPathComponent()
                    .appendingPathComponent(payloadDirectoryName, isDirectory: true)
                    .appendingPathComponent(reportIDHex, isDirectory: true)
            }

            static func files(in payloadDirectory: URL) -> [URL] {
                do {
                    return try FileManager.default.contentsOfDirectory(
                        at: payloadDirectory,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles]
                    )
                } catch {
                    SentrySDKLog.debug("Failed to list attachment files in \(payloadDirectory.path): \(error)")
                    return []
                }
            }

            static func removeConsumedPayloadDirectories(for attachmentPaths: [URL]) {
                let directories = attachmentPaths
                    .map { $0.deletingLastPathComponent() }
                    .filter { path in
                        let id = path.lastPathComponent

                        return isReportIDHex(id) &&
                            path.deletingLastPathComponent().lastPathComponent == payloadDirectoryName
                    }
                    .reduce(into: Set<URL>()) { partialResult, item in
                        partialResult.insert(item)
                    }

                directories.forEach { try? FileManager.default.removeItem(at: $0) }
            }

            static func removeOrphanedPayloadDirectories(at installPath: URL, keeping reportIDs: Set<Int64>) {
                let root = installPath.appendingPathComponent(payloadDirectoryName, isDirectory: true)
                guard FileManager.default.fileExists(atPath: root.path) else {
                    return
                }

                let kept = Set(reportIDs.map(reportIDHex))
                let directories: [URL]
                do {
                    directories = try FileManager.default.contentsOfDirectory(
                        at: root,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles]
                    )
                    .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
                    .filter { isReportIDHex($0.lastPathComponent) }
                    .filter { !kept.contains($0.lastPathComponent.lowercased()) }
                } catch {
                    SentrySDKLog.debug(
                        "Failed to list attachment payload directories in \(root.path): \(error)"
                    )
                    return
                }

                directories.forEach { url in
                    do {
                        try FileManager.default.removeItem(at: url)
                    } catch {
                        SentrySDKLog.debug(
                            "Failed to remove orphaned attachment payload directory \(url.path): \(error)"
                        )
                    }
                }
            }

            static func reportIDHex(_ reportID: Int64) -> String {
                String(format: "%016llx", UInt64(bitPattern: reportID))
            }

            private static func isReportIDHex(_ name: String) -> Bool {
                name.count == 16 && name.allSatisfy(\.isHexDigit)
            }
        }

        private let _monitorId: UnsafeMutablePointer<CChar> = strdup(sentrykscrash_attachmentsMonitorID)

        let api: UnsafeMutablePointer<KSCrashMonitorAPI>

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

        private static let apiInitCallback: InitCallback = { callbacks, _ in
            sentrykscrash_attachments_setSidecarPathProvider(callbacks?.pointee.getReportSidecarPath)
        }

        private static let monitorIDCallback: MonitorIDCallback = { context in
            guard let monitor = SentryKSCrash.AttachmentsMonitor.from(context) else {
                SentrySDKLog.debug("Attachments monitor context is nil when reading monitor ID")
                return nil
            }
            return UnsafePointer(monitor._monitorId)
        }

        private static let monitorFlagsCallback: MonitorFlagsCallback = { _ in KSCrashMonitorFlagPlugin }

        private static let addContextualInfoCallback: AddContextualInfoCallback = { _, _ in }

        private static let notifyPostSystemEnableCallback: NotifyCallback = { _ in }

        private static let createStitchedReportCallback: StitchCallback = { reportDict, sidecarPath, scope, context in
            guard let reportDict else {
                SentrySDKLog.debug("Not stitching attachments because KSCrash report dictionary is nil")
                return nil
            }
            guard let monitor = SentryKSCrash.AttachmentsMonitor.from(context) else {
                SentrySDKLog.debug("Not stitching attachments because monitor context is nil")
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
                setEnabled: sentrykscrash_attachments_setEnabled,
                isEnabled: sentrykscrash_attachments_isEnabled,
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

extension SentryKSCrash.AttachmentsMonitor {
    func setScreenshotWriter(_ writer: SentryKSCrashAttachmentsScreenshotWriter?) {
        sentrykscrash_attachments_setScreenshotWriter(writer)
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
        guard scope == KSCrashSidecarScopeReport else {
            SentrySDKLog.debug("Not stitching attachments because sidecar scope is not report")
            return Unmanaged.passRetained(reportDict)
        }
        guard let sidecarPath else {
            SentrySDKLog.debug("Not stitching attachments because sidecar path is nil")
            return Unmanaged.passRetained(reportDict)
        }

        let sidecar = URL(fileURLWithPath: String(cString: sidecarPath))
        guard Marker.isValid(at: sidecar) else {
            SentrySDKLog.debug("Not stitching attachments because marker is missing or invalid at \(sidecar.path)")
            return Unmanaged.passRetained(reportDict)
        }
        guard let payloadDirectory = Layout.payloadDirectory(from: sidecar) else {
            SentrySDKLog.debug("Not stitching attachments because payload directory could not be derived from \(sidecar.path)")
            return Unmanaged.passRetained(reportDict)
        }

        let incoming = Layout.files(in: payloadDirectory).map(\.path)

        guard !incoming.isEmpty else {
            SentrySDKLog.debug("Not stitching attachments because payload directory is empty at \(payloadDirectory.path)")
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
            SentrySDKLog.debug("Not stitching attachments because report already contains the payload paths")
            return Unmanaged.passRetained(reportDict)
        }

        let stitched = NSMutableDictionary(dictionary: original)
        stitched[Self.attachmentsReportKey] = merged
        SentrySDKLog.debug("Stitched \(incoming.count) attachment path(s) into crash report")
        return Unmanaged.passRetained(stitched as CFDictionary)
    }
}

#endif
