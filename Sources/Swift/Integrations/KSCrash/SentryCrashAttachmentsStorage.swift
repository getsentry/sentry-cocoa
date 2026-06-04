// Sources/Swift/Integrations/KSCrash/SentryCrashAttachmentsStorage.swift
@_implementationOnly import _SentryPrivate
import Foundation

enum SentryCrashAttachmentsStorage {
    // Set by KSCrashIntegration at install time.
    nonisolated(unsafe) static var basePath: String?

    // Set by SentryScreenshotIntegration / SentryViewHierarchyIntegration.
    nonisolated(unsafe) static var screenshotCallback: ((String) -> Void)?
    nonisolated(unsafe) static var viewHierarchyCallback: ((String) -> Void)?

    static func attachmentsDirectory(for reportIDHex: String) -> URL? {
        guard let base = basePath else { return nil }
        return URL(fileURLWithPath: base).appendingPathComponent(reportIDHex)
    }

    static func attachments(for reportIDHex: String) -> [Attachment] {
        guard let dir = attachmentsDirectory(for: reportIDHex) else { return [] }
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return [] }

        return files.compactMap { url in
            let name = url.lastPathComponent
            switch url.pathExtension {
            case "png":
                return Attachment(path: url.path, filename: name, contentType: "image/png")
            case "json":
                let attachmentType: SentryAttachmentType = name == "view-hierarchy.json"
                    ? .viewHierarchy : .eventAttachment
                return Attachment(
                    path: url.path,
                    filename: name,
                    contentType: "application/json",
                    attachmentType: attachmentType
                )
            default:
                return nil
            }
        }
    }

    static func cleanup(for reportIDHex: String) {
        guard let dir = attachmentsDirectory(for: reportIDHex) else { return }
        try? FileManager.default.removeItem(at: dir)
    }
}
