import Foundation

enum ManagedRuntimeSignalMarker {
    static let expectedText = "CrashE2EFakeManagedRuntimeSignalHandler"

    static func assertExists(at markerPath: URL, platform: String) throws {
        guard FileManager.default.fileExists(atPath: markerPath.path) else {
            try fail("Expected fake managed runtime signal handler marker for \(platform): \(markerPath.path)")
        }

        let contents = try String(contentsOf: markerPath, encoding: .utf8)
        guard contents.contains(expectedText) else {
            try fail("Expected fake managed runtime signal handler marker text in \(markerPath.path)")
        }
    }
}
