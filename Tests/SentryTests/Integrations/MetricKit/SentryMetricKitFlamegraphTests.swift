@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import _SentryPrivate
import XCTest

#if os(iOS) || os(macOS) || os(visionOS)
import MetricKit

final class SentryMetricKitFlamegraphTests: SentrySDKIntegrationTestsBase {

    func testDidReceive_whenFlamegraphAttachmentMode_shouldAttachFlamegraph() throws {
        // -- Arrange --
        givenSdkWithHub(scope: Scope())
        let options = Options()
        options.enableMetricKit = true
        options.experimental.metrickit.hangReportingMode = .flamegraphAttachment
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))
        defer { sut.uninstall() }
        let diagnostic = TestMXHangDiagnostic()
        diagnostic.overrides.callStackTree.overrides.jsonRepresentation = hangTreeJSON
        let payload = TestMXDiagnosticPayload()
        payload.overrides.hangDiagnostic = [diagnostic]

        // -- Act --
        sut.mxManager.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { capturedEvent, _, _ in
            let event = try XCTUnwrap(capturedEvent)
            let exception = try XCTUnwrap(event.exceptions?.first)
            XCTAssertNil(exception.stacktrace)
            XCTAssertNil(exception.threadId)
            XCTAssertTrue(event.threads?.isEmpty ?? true)
            XCTAssertEqual(exception.mechanism?.type, "mx_hang_diagnostic")
            let attachment = try XCTUnwrap(capturedHintAttachments().first { $0.filename == "flamegraph.json" })
            XCTAssertEqual(attachment.contentType, "application/json")
            XCTAssertEqual(attachment.attachmentType, .flamegraph)
            let item = try XCTUnwrap(SentryEnvelopeItem(attachment: attachment, maxAttachmentSize: 20 * 1_024 * 1_024))
            XCTAssertEqual(item.header.serialize()["attachment_type"] as? String, "event.flamegraph")
            XCTAssertEqual(item.header.length, UInt(try XCTUnwrap(attachment.data).count))
            let data = try XCTUnwrap(attachment.data)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertEqual(json["version"] as? String, "1")
            XCTAssertEqual(json["platform"] as? String, "cocoa")
            let frames = try XCTUnwrap(json["frames"] as? [[String: Any]])
            XCTAssertEqual(frames.compactMap { $0["instruction_addr"] as? String }, ["0x0000000000001001", "0x0000000000001002", "0x0000000000001003", "0x0000000000001004"])
            let trees = try XCTUnwrap(json["trees"] as? [[String: Any]])
            XCTAssertEqual(trees.count, 1)
            XCTAssertNil(trees.first?["thread_id"])
            XCTAssertEqual(trees.first?["thread_attributed"] as? Bool, false)
            XCTAssertEqual(trees.first?["roots"] as? [Int], [0])
            let nodes = try XCTUnwrap(json["nodes"] as? [[String: Any]])
            XCTAssertEqual(nodes.compactMap { $0["frame_id"] as? Int }, [0, 1, 2, 3])
            XCTAssertEqual(nodes.compactMap { $0["sample_count"] as? Int }, [100, 100, 50, 50])
            XCTAssertEqual(try XCTUnwrap(nodes.element(at: 0))["children"] as? [Int], [1])
            XCTAssertEqual(try XCTUnwrap(nodes.element(at: 1))["children"] as? [Int], [2, 3])
            XCTAssertNil(try XCTUnwrap(nodes.element(at: 2))["children"])
            XCTAssertNil(try XCTUnwrap(nodes.element(at: 3))["children"])
            let debugMeta = try XCTUnwrap(json["debug_meta"] as? [String: Any])
            XCTAssertFalse(try XCTUnwrap(debugMeta["images"] as? [[String: Any]]).isEmpty)
        }
    }

    func testDidReceive_whenFlamegraphIsRejected_shouldPreserveFlattenedHangTree() throws {
        // -- Arrange --
        givenSdkWithHub(scope: Scope())
        let options = Options()
        options.enableMetricKit = true
        options.experimental.metrickit.hangReportingMode = .flamegraphAttachment
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))
        defer { sut.uninstall() }
        let diagnostic = TestMXHangDiagnostic()
        let json = try XCTUnwrap(String(data: hangTreeJSON, encoding: .utf8))
            .replacingOccurrences(of: "\"sampleCount\":100,\"subFrames\":[", with: "\"sampleCount\":99,\"subFrames\":[")
        diagnostic.overrides.callStackTree.overrides.jsonRepresentation = Data(json.utf8)
        let payload = TestMXDiagnosticPayload()
        payload.overrides.hangDiagnostic = [diagnostic]

        // -- Act --
        sut.mxManager.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { capturedEvent, _, _ in
            let event = try XCTUnwrap(capturedEvent)
            let exception = try XCTUnwrap(event.exceptions?.first)
            let frames = try XCTUnwrap(exception.stacktrace).frames
            XCTAssertEqual(frames.map(\.instructionAddress), ["0x0000000000001001", "0x0000000000001002", "0x0000000000001003", "0x0000000000001004"])
            XCTAssertEqual(frames.map(\.parentIndex), [-1, 0, 1, 1])
            XCTAssertEqual(frames.map(\.sampleCount), [99, 99, 50, 50])
            XCTAssertEqual(exception.threadId, event.threads?.first?.threadId)
            XCTAssertFalse(event.threads?.isEmpty ?? true)
            XCTAssertFalse(event.debugMeta?.isEmpty ?? true)
            XCTAssertFalse(try capturedHintAttachments().contains { $0.filename == "flamegraph.json" })
        }
    }

    func testDidReceive_whenDefaultMode_shouldPreserveFlattenedHangTree() throws {
        // -- Arrange --
        givenSdkWithHub(scope: Scope())
        let options = Options()
        options.enableMetricKit = true
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))
        defer { sut.uninstall() }
        let diagnostic = TestMXHangDiagnostic()
        diagnostic.overrides.callStackTree.overrides.jsonRepresentation = hangTreeJSON
        let payload = TestMXDiagnosticPayload()
        payload.overrides.hangDiagnostic = [diagnostic]

        // -- Act --
        sut.mxManager.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { capturedEvent, _, _ in
            let event = try XCTUnwrap(capturedEvent)
            let frames = try XCTUnwrap(event.exceptions?.first?.stacktrace).frames
            XCTAssertEqual(frames.map(\.instructionAddress), ["0x0000000000001001", "0x0000000000001002", "0x0000000000001003", "0x0000000000001004"])
            XCTAssertEqual(frames.map(\.parentIndex), [-1, 0, 1, 1])
            XCTAssertEqual(frames.map(\.sampleCount), [100, 100, 50, 50])
        }
    }

    func testFlamegraphAttachment_whenFramesRepeat_shouldDeduplicateAcrossSeparateTrees() throws {
        // -- Arrange --
        let tree = try JSONDecoder().decode(SentryMXCallStackTree.self, from: hangTreeJSON)
        let repeatedTree = SentryMXCallStackTree(callStacks: tree.callStacks + tree.callStacks, callStackPerThread: false)

        // -- Act --
        let attachment = try XCTUnwrap(repeatedTree.flamegraphAttachment(inAppLogic: SentryInAppLogic(inAppIncludes: ["App"])))

        // -- Assert --
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(attachment.data)) as? [String: Any])
        XCTAssertEqual((json["frames"] as? [[String: Any]])?.count, 4)
        let trees = try XCTUnwrap(json["trees"] as? [[String: Any]])
        XCTAssertEqual(trees.count, 2)
        XCTAssertEqual(trees.first?["roots"] as? [Int], [0])
        XCTAssertEqual(trees.last?["roots"] as? [Int], [4])
        let nodes = try XCTUnwrap(json["nodes"] as? [[String: Any]])
        XCTAssertEqual(nodes.compactMap { $0["frame_id"] as? Int }, [0, 1, 2, 3, 0, 1, 2, 3])
        XCTAssertEqual(nodes.compactMap { $0["sample_count"] as? Int }, [100, 100, 50, 50, 100, 100, 50, 50])
        XCTAssertEqual(try XCTUnwrap(nodes.element(at: 4))["children"] as? [Int], [5])
        XCTAssertEqual(try XCTUnwrap(nodes.element(at: 5))["children"] as? [Int], [6, 7])
    }

    func testFlamegraphAttachment_whenMultipleRootsContainRecursiveFrames_shouldKeepDistinctNodes() throws {
        // -- Arrange --
        let leaf = SentryMXFrame(binaryUUID: nil, offsetIntoBinaryTextSegment: 0, binaryName: nil, address: 4_096, subFrames: nil, sampleCount: 2)
        let root = SentryMXFrame(binaryUUID: nil, offsetIntoBinaryTextSegment: 0, binaryName: nil, address: 4_096, subFrames: [leaf], sampleCount: 3)
        let tree = SentryMXCallStackTree(callStacks: [
            SentryMXCallStack(threadAttributed: true, callStackRootFrames: [root, leaf])
        ], callStackPerThread: true)

        // -- Act --
        let attachment = try XCTUnwrap(tree.flamegraphAttachment(inAppLogic: SentryInAppLogic(inAppIncludes: [])))

        // -- Assert --
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(attachment.data)) as? [String: Any])
        XCTAssertEqual((json["frames"] as? [[String: Any]])?.count, 1)
        let trees = try XCTUnwrap(json["trees"] as? [[String: Any]])
        XCTAssertEqual(trees.first?["roots"] as? [Int], [0, 1])
        let nodes = try XCTUnwrap(json["nodes"] as? [[String: Any]])
        XCTAssertEqual(nodes.compactMap { $0["frame_id"] as? Int }, [0, 0, 0])
        XCTAssertEqual(nodes.compactMap { $0["sample_count"] as? Int }, [3, 2, 2])
        XCTAssertEqual(try XCTUnwrap(nodes.element(at: 0))["children"] as? [Int], [2])
        XCTAssertNil(try XCTUnwrap(nodes.element(at: 1))["children"])
        XCTAssertNil(try XCTUnwrap(nodes.element(at: 2))["children"])
    }

    func testFlamegraphAttachment_whenSampleCountsAreInvalid_shouldOmitAttachment() throws {
        for invalidCount in [0, -1, 99, 9_007_199_254_740_992] {
            // -- Arrange --
            let json = try XCTUnwrap(String(data: hangTreeJSON, encoding: .utf8))
                .replacingOccurrences(of: "\"sampleCount\":100,\"subFrames\":[", with: "\"sampleCount\":\(invalidCount),\"subFrames\":[", options: [], range: nil)
            let tree = try JSONDecoder().decode(SentryMXCallStackTree.self, from: Data(json.utf8))

            // -- Act --
            let attachment = tree.flamegraphAttachment(inAppLogic: SentryInAppLogic(inAppIncludes: ["App"]))

            // -- Assert --
            XCTAssertNil(attachment, "Invalid count: \(invalidCount)")
        }
    }

    func testFlamegraphAttachment_whenBinaryMetadataIsMissing_shouldRetainAddresses() throws {
        // -- Arrange --
        let tree = SentryMXCallStackTree(callStacks: [SentryMXCallStack(threadAttributed: nil, callStackRootFrames: [
            SentryMXFrame(binaryUUID: nil, offsetIntoBinaryTextSegment: 0, binaryName: nil, address: 4_096, subFrames: nil, sampleCount: 1)
        ])], callStackPerThread: true)

        // -- Act --
        let attachment = try XCTUnwrap(tree.flamegraphAttachment(inAppLogic: SentryInAppLogic(inAppIncludes: [])))

        // -- Assert --
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(attachment.data)) as? [String: Any])
        let frames = try XCTUnwrap(json["frames"] as? [[String: Any]])
        XCTAssertEqual(frames.first?["instruction_addr"] as? String, "0x0000000000001000")
        let trees = try XCTUnwrap(json["trees"] as? [[String: Any]])
        XCTAssertNil(trees.first?["thread_attributed"])
        XCTAssertNil(trees.first?["thread_id"])
        XCTAssertEqual(typeForSentryAttachmentName("event.flamegraph"), .flamegraph)
    }

    private func capturedHintAttachments() throws -> [Attachment] {
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient)
        XCTAssertEqual(client.captureEventWithScopeAndHintInvocations.count, 1)
        let capture = try XCTUnwrap(client.captureEventWithScopeAndHintInvocations.first)
        return capture.hint?.attachments ?? []
    }

    private var hangTreeJSON: Data {
        Data("""
        {"callStackPerThread":true,"callStacks":[{"threadAttributed":false,"callStackRootFrames":[
          {"binaryUUID":"00000000-0000-0000-0000-000000000001","binaryName":"App","address":4097,"offsetIntoBinaryTextSegment":1,"sampleCount":100,"subFrames":[
            {"binaryUUID":"00000000-0000-0000-0000-000000000001","binaryName":"App","address":4098,"offsetIntoBinaryTextSegment":2,"sampleCount":100,"subFrames":[
              {"binaryUUID":"00000000-0000-0000-0000-000000000001","binaryName":"App","address":4099,"offsetIntoBinaryTextSegment":3,"sampleCount":50},
              {"binaryUUID":"00000000-0000-0000-0000-000000000001","binaryName":"App","address":4100,"offsetIntoBinaryTextSegment":4,"sampleCount":50}
            ]}
          ]}
        ]}]}
        """.utf8)
    }

}

#endif
