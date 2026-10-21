#if SWIFT_PACKAGE
@testable import SentrySwift
#else
@testable import Sentry
#endif
import XCTest

final class SentryRelayWireFormatAttachmentsFlameGraphTests: XCTestCase {
    func testEncodeNode_whenChildrenAreNil_shouldOmitThemAndRetainExactSampleCount() throws {
        // -- Arrange --
        let node = SentryRelayWireFormat.Attachments.FlameGraph.Node(frameID: .init(0), sampleCount: 9_007_199_254_740_991, children: nil)

        // -- Act --
        let actual = try encodedJSON(node)

        // -- Assert --
        XCTAssertEqual(actual, #"{"frame_id":0,"sample_count":9007199254740991}"#)
    }

    func testEncodeNode_whenChildrenAreEmpty_shouldEncodeEmptyArray() throws {
        // -- Arrange --
        let node = SentryRelayWireFormat.Attachments.FlameGraph.Node(frameID: .init(1), sampleCount: 6, children: [])

        // -- Act --
        let actual = try encodedJSON(node)

        // -- Assert --
        XCTAssertEqual(actual, #"{"children":[],"frame_id":1,"sample_count":6}"#)
    }

    func testEncodeTree_whenAttributionIsUnknown_shouldOmitAttributionAndThreadID() throws {
        // -- Arrange --
        let tree = SentryRelayWireFormat.Attachments.FlameGraph.Tree(
            roots: [.init(0)],
            threadAttributed: nil
        )

        // -- Act --
        let actual = try encodedJSON(tree)

        // -- Assert --
        XCTAssertEqual(actual, #"{"roots":[0]}"#)
    }

    func testEncodeTree_whenNotAttributed_shouldPreserveFalse() throws {
        // -- Arrange --
        let tree = SentryRelayWireFormat.Attachments.FlameGraph.Tree(
            roots: [.init(0)],
            threadAttributed: false
        )

        // -- Act --
        let actual = try encodedJSON(tree)

        // -- Assert --
        XCTAssertEqual(actual, #"{"roots":[0],"thread_attributed":false}"#)
    }

    func testEncodeFlameGraph_whenTreesShareFrames_shouldPreserveFlatPayloadAndArrayOrder() throws {
        // -- Arrange --
        let payload = SentryRelayWireFormat.Attachments.FlameGraph(
            frames: [
                SentryRelayWireFormat.Profiling.V2.Frame(instructionAddress: "0x100001000", package: "ExampleApp", inApp: true),
                SentryRelayWireFormat.Profiling.V2.Frame(instructionAddress: "0x100001200", package: nil, inApp: nil)
            ],
            nodes: [
                SentryRelayWireFormat.Attachments.FlameGraph.Node(frameID: .init(0), sampleCount: 10, children: [.init(1)]),
                SentryRelayWireFormat.Attachments.FlameGraph.Node(frameID: .init(1), sampleCount: 6, children: nil),
                SentryRelayWireFormat.Attachments.FlameGraph.Node(frameID: .init(1), sampleCount: 4, children: nil),
                SentryRelayWireFormat.Attachments.FlameGraph.Node(frameID: .init(0), sampleCount: 2, children: nil)
            ],
            trees: [
                SentryRelayWireFormat.Attachments.FlameGraph.Tree(roots: [.init(0)], threadAttributed: true),
                SentryRelayWireFormat.Attachments.FlameGraph.Tree(roots: [.init(2), .init(3)], threadAttributed: nil)
            ],
            debugMeta: SentryRelayWireFormat.EventPayloads.DebugMeta(images: [
                SentryRelayWireFormat.EventPayloads.DebugMeta.Image(
                    type: "macho", debugID: "84a04d24-0e60-3810-a8c0-90a65e2df61a", codeFile: "ExampleApp",
                    imageAddress: "0x100000000", imageSize: 8_192, imageVmAddress: nil
                )
            ])
        )

        // -- Act --
        let actual = try encodedJSON(payload)

        // -- Assert --
        let expected = #"{"debug_meta":{"images":[{"code_file":"ExampleApp","debug_id":"84a04d24-0e60-3810-a8c0-90a65e2df61a","image_addr":"0x100000000","image_size":8192,"type":"macho"}]},"#
            + #""frames":[{"in_app":true,"instruction_addr":"0x100001000","package":"ExampleApp"},{"instruction_addr":"0x100001200"}],"#
            + #""nodes":[{"children":[1],"frame_id":0,"sample_count":10},{"frame_id":1,"sample_count":6},{"frame_id":1,"sample_count":4},{"frame_id":0,"sample_count":2}],"platform":"cocoa","#
            + #""trees":[{"roots":[0],"thread_attributed":true},{"roots":[2,3]}],"version":"1"}"#
        XCTAssertEqual(actual, expected)
    }

    private func encodedJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

}
