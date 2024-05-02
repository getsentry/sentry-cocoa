import _SentryPrivate
@testable import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)

final class SentryContinuousProfilerTests: XCTestCase {
    private var fixture: SentryProfileTestFixture!
    
    override class func setUp() {
        super.setUp()
        SentryLog.configure(true, diagnosticLevel: .debug)
    }
    
    override func setUp() {
        super.setUp()
        fixture = SentryProfileTestFixture()
    }
    
    func testStartingAndStoppingContinuousProfiler() throws {
        try performContinuousProfilingTest()
    }
}

private extension SentryContinuousProfilerTests {
    func performContinuousProfilingTest() throws {
        SentryContinuousProfiler.start()
        
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        
        try addMockSamples()
        SentryContinuousProfiler.stop()
        
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        
        try assertValidContinuousProfileData()

        //swiftlint:disable todo
        // TODO: assert valid continuous profiling data when schema changes are implemented
        //swiftlint:enable todo
    }
    
    func addMockSamples(threadMetadata: SentryProfileTestFixture.ThreadMetadata = SentryProfileTestFixture.ThreadMetadata(id: 1, priority: 2, name: "main"), addresses: [NSNumber] = [0x3, 0x4, 0x5]) throws {
        let state = try XCTUnwrap(SentryContinuousProfiler.profiler()?.state)
        fixture.currentDateProvider.advanceBy(nanoseconds: 1)
        SentryProfilerMocksSwiftCompatible.appendMockBacktrace(to: state, threadID: threadMetadata.id, threadPriority: threadMetadata.priority, threadName: threadMetadata.name, addresses: addresses)
        fixture.currentDateProvider.advanceBy(nanoseconds: 1)
        SentryProfilerMocksSwiftCompatible.appendMockBacktrace(to: state, threadID: threadMetadata.id, threadPriority: threadMetadata.priority, threadName: threadMetadata.name, addresses: addresses)
        fixture.currentDateProvider.advanceBy(nanoseconds: 1)
        SentryProfilerMocksSwiftCompatible.appendMockBacktrace(to: state, threadID: threadMetadata.id, threadPriority: threadMetadata.priority, threadName: threadMetadata.name, addresses: addresses)
    }
    
    func getLatestProfileData() throws -> Data {
        let envelope = try XCTUnwrap(self.fixture.client?.captureEnvelopeInvocations.last)

        XCTAssertEqual(1, envelope.items.count)
        let profileItem = try XCTUnwrap(envelope.items.first)
        XCTAssertEqual("profile_chunk", profileItem.header.type)
        return profileItem.data
    }
    
    func assertValidContinuousProfileData(transactionEnvironment: String = kSentryDefaultEnvironment, expectedAddresses: [NSNumber]? = nil, expectedThreadMetadata: [SentryProfileTestFixture.ThreadMetadata]? = nil, appStartProfile: Bool = false) throws {
        let data = try getLatestProfileData()
        let profile = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertNotNil(profile["version"])

        let platform = try XCTUnwrap(profile["platform"] as? String)
        XCTAssertEqual("cocoa", platform)

        XCTAssertEqual(transactionEnvironment, try XCTUnwrap(profile["environment"] as? String))

        let bundleID = Bundle.main.object(forInfoDictionaryKey: kCFBundleIdentifierKey as String) ?? "(null)"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "(null)"
        let build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) ?? "(null)"
        let expectedReleaseString = "\(bundleID)@\(version)+\(build)"
        let actualReleaseString = try XCTUnwrap(profile["release"] as? String)
        XCTAssertEqual(actualReleaseString, expectedReleaseString)

        XCTAssertNotEqual(SentryId.empty, SentryId(uuidString: try XCTUnwrap(profile["profile_id"] as? String)))

        let debugMeta = try XCTUnwrap(profile["debug_meta"] as? [String: Any])
        let images = try XCTUnwrap(debugMeta["images"] as? [[String: Any]])
        XCTAssertFalse(images.isEmpty)
        let firstImage = images[0]
        XCTAssertFalse(try XCTUnwrap(firstImage["code_file"] as? String).isEmpty)
        XCTAssertFalse(try XCTUnwrap(firstImage["debug_id"] as? String).isEmpty)
        XCTAssertFalse(try XCTUnwrap(firstImage["image_addr"] as? String).isEmpty)
        XCTAssertGreaterThan(try XCTUnwrap(firstImage["image_size"] as? Int), 0)
        XCTAssertEqual(try XCTUnwrap(firstImage["type"] as? String), "macho")

        let sampledProfile = try XCTUnwrap(profile["profile"] as? [String: Any])
        let threadMetadata = try XCTUnwrap(sampledProfile["thread_metadata"] as? [String: [String: Any]])
        XCTAssertFalse(threadMetadata.isEmpty)
        if let expectedThreadMetadata = expectedThreadMetadata {
            try expectedThreadMetadata.forEach {
                let actualThreadMetadata = try XCTUnwrap(threadMetadata["\($0.id)"])
                let actualThreadPriority = try XCTUnwrap(actualThreadMetadata["priority"] as? Int32)
                XCTAssertEqual(actualThreadPriority, $0.priority)
                let actualThreadName = try XCTUnwrap(actualThreadMetadata["name"] as? String)
                XCTAssertEqual(actualThreadName, $0.name)
            }
        } else {
            XCTAssertFalse(try threadMetadata.values.compactMap { $0["priority"] }.filter { try XCTUnwrap($0 as? Int) > 0 }.isEmpty)
            XCTAssertFalse(try threadMetadata.values.compactMap { $0["name"] }.filter { try XCTUnwrap($0 as? String) == "main" }.isEmpty)
        }

        let samples = try XCTUnwrap(sampledProfile["samples"] as? [[String: Any]])
        XCTAssertFalse(samples.isEmpty)

        let frames = try XCTUnwrap(sampledProfile["frames"] as? [[String: Any]])
        XCTAssertFalse(frames.isEmpty)
        XCTAssertFalse(try XCTUnwrap(frames[0]["instruction_addr"] as? String).isEmpty)
        XCTAssertFalse(try XCTUnwrap(frames[0]["function"] as? String).isEmpty)

        let stacks = try XCTUnwrap(sampledProfile["stacks"] as? [[Int]])
        var foundAtLeastOneNonEmptySample = false
        XCTAssertFalse(stacks.isEmpty)
        for stack in stacks {
            guard !stack.isEmpty else { continue }
            foundAtLeastOneNonEmptySample = true
            for frameIdx in stack {
                XCTAssertNotNil(frames[frameIdx])
            }
        }
        XCTAssert(foundAtLeastOneNonEmptySample)

        for sample in samples {
            XCTAssertNotNil(sample["timestamp"] as? NSNumber)
            XCTAssertNotNil(sample["thread_id"])
            let stackIDEntry = try XCTUnwrap(sample["stack_id"])
            let stackID = try XCTUnwrap(stackIDEntry as? Int)
            XCTAssertNotNil(stacks[stackID])
        }
    }
}

#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
