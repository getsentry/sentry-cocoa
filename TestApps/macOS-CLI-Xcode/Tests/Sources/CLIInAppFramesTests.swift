import Foundation
import XCTest

final class CLIInAppFramesTests: XCTestCase {
    func testCLI_whenLaunchedDirectly_shouldClassifyMainExecutableFrames() throws {
        // -- Arrange --
        let executable = cliExecutableURL

        // -- Act & Assert --
        try assertMainExecutableClassification(executable: executable)
    }

    func testCLI_whenLaunchedThroughSymlink_shouldClassifyMainExecutableFrames() throws {
        // -- Arrange --
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try FileManager.default.removeItem(at: directory)
        }
        let symlink = directory.appendingPathComponent("linked-cli")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: cliExecutableURL)

        // -- Act & Assert --
        try assertMainExecutableClassification(executable: symlink)
    }

    private var cliExecutableURL: URL {
        Bundle(for: CLIInAppFramesTests.self).bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("macOS-CLI-Xcode")
    }

    private func assertMainExecutableClassification(
        executable: URL,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let process = Process()
        process.executableURL = executable
        process.arguments = ["--validate-in-app-frames"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        let terminated = expectation(description: "CLI terminated")
        process.terminationHandler = { _ in terminated.fulfill() }

        try process.run()
        wait(for: [terminated], timeout: 30)
        guard !process.isRunning else {
            process.terminate()
            return
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        let text = try XCTUnwrap(String(data: data, encoding: .utf8), file: file, line: line)
        XCTAssertEqual(process.terminationReason, .exit, text, file: file, line: line)
        XCTAssertEqual(process.terminationStatus, 0, text, file: file, line: line)
        XCTAssertTrue(text.contains("CLI main executable frame classification validated"), text, file: file, line: line)
    }
}
