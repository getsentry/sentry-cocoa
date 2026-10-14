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
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))
        defer { sut.uninstall() }
        let diagnostic = TestMXHangDiagnostic()
        diagnostic.overrides.callStackTree.overrides.jsonRepresentation = hangTreeJSON
        let payload = TestMXDiagnosticPayload()
        payload.overrides.hangDiagnostic = [diagnostic]

        // -- Act --
        sut.mxManager.didReceive([payload])

        // -- Assert --
        try assertEventWithScopeCaptured { capturedEvent, scope, _ in
            let event = try XCTUnwrap(capturedEvent)
            let exception = try XCTUnwrap(event.exceptions?.first)
            XCTAssertNil(exception.stacktrace)
            XCTAssertNil(exception.threadId)
            XCTAssertTrue(event.threads?.isEmpty ?? true)
            XCTAssertEqual(exception.mechanism?.type, "mx_hang_diagnostic")
            let attachment = try XCTUnwrap(scope?.attachments.first { $0.filename == "flamegraph.json" })
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
            let roots = try XCTUnwrap(trees.first?["roots"] as? [[String: Any]])
            XCTAssertEqual(roots.first?["sample_count"] as? Int, 100)
            XCTAssertEqual(roots.first?["frame_id"] as? Int, 0)
            let children = try XCTUnwrap(roots.first?["children"] as? [[String: Any]])
            let leaves = try XCTUnwrap(children.first?["children"] as? [[String: Any]])
            XCTAssertEqual(leaves.compactMap { $0["sample_count"] as? Int }, [50, 50])
            XCTAssertEqual(leaves.compactMap { $0["frame_id"] as? Int }, [2, 3])
            let debugMeta = try XCTUnwrap(json["debug_meta"] as? [String: Any])
            XCTAssertFalse(try XCTUnwrap(debugMeta["images"] as? [[String: Any]]).isEmpty)
        }
    }

    func testDidReceive_whenDefaultMode_shouldPreserveFlattenedHangTree() throws {
        // -- Arrange --
        givenSdkWithHub(scope: Scope())
        let options = Options()
        options.enableMetricKit = true
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))
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
        let tree = try SentryMXCallStackTree.from(data: hangTreeJSON)
        let repeatedTree = SentryMXCallStackTree(callStacks: tree.callStacks + tree.callStacks, callStackPerThread: false)

        // -- Act --
        let attachment = try XCTUnwrap(repeatedTree.flamegraphAttachment(inAppLogic: SentryInAppLogic(inAppIncludes: ["App"])))

        // -- Assert --
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(attachment.data)) as? [String: Any])
        XCTAssertEqual((json["frames"] as? [[String: Any]])?.count, 4)
        let trees = try XCTUnwrap(json["trees"] as? [[String: Any]])
        XCTAssertEqual(trees.count, 2)
        let firstRoots = try XCTUnwrap(trees.first?["roots"] as? [[String: Any]])
        let lastRoots = try XCTUnwrap(trees.last?["roots"] as? [[String: Any]])
        XCTAssertEqual(firstRoots.first?["frame_id"] as? Int, lastRoots.first?["frame_id"] as? Int)
        XCTAssertEqual(firstRoots.first?["sample_count"] as? Int, 100)
        XCTAssertEqual(lastRoots.first?["sample_count"] as? Int, 100)
    }

    func testFlamegraphAttachment_whenSampleCountsAreInvalid_shouldOmitAttachment() throws {
        for invalidCount in [0, -1, 99, 9_007_199_254_740_992] {
            // -- Arrange --
            let json = try XCTUnwrap(String(data: hangTreeJSON, encoding: .utf8))
                .replacingOccurrences(of: "\"sampleCount\":100,\"subFrames\":[", with: "\"sampleCount\":\(invalidCount),\"subFrames\":[", options: [], range: nil)
            let tree = try SentryMXCallStackTree.from(data: Data(json.utf8))

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
