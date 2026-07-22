@_spi(Private) @testable import Sentry
import XCTest

class SentryDataCategoryMapperTests: XCTestCase {

    func testEnvelopeItemType() {
        XCTAssertEqual(SentryDataCategory(itemType: "event"), .error)
        XCTAssertEqual(SentryDataCategory(itemType: "session"), .session)
        XCTAssertEqual(SentryDataCategory(itemType: "transaction"), .transaction)
        XCTAssertEqual(SentryDataCategory(itemType: "attachment"), .attachment)
        XCTAssertEqual(SentryDataCategory(itemType: "profile"), .profile)
        XCTAssertEqual(SentryDataCategory(itemType: "profile_chunk"), .profileChunkUI)
        XCTAssertEqual(SentryDataCategory(itemType: "statsd"), .metricBucket)
        XCTAssertEqual(SentryDataCategory(itemType: "replay_video"), .replay)
        XCTAssertEqual(SentryDataCategory(itemType: "feedback"), .feedback)
        XCTAssertEqual(SentryDataCategory(itemType: "log"), .logItem)
        XCTAssertEqual(SentryDataCategory(itemType: "trace_metric"), .traceMetric)
        XCTAssertEqual(SentryDataCategory(itemType: "unknown item type"), .default)
    }

    func testMapStringToCategory() {
        XCTAssertEqual(SentryDataCategory(name: ""), .all)
        XCTAssertEqual(SentryDataCategory(name: "default"), .default)
        XCTAssertEqual(SentryDataCategory(name: "error"), .error)
        XCTAssertEqual(SentryDataCategory(name: "session"), .session)
        XCTAssertEqual(SentryDataCategory(name: "transaction"), .transaction)
        XCTAssertEqual(SentryDataCategory(name: "attachment"), .attachment)
        XCTAssertEqual(SentryDataCategory(name: "profile"), .profile)
        XCTAssertEqual(SentryDataCategory(name: "profile_chunk_ui"), .profileChunkUI)
        XCTAssertEqual(SentryDataCategory(name: "metric_bucket"), .metricBucket)
        XCTAssertEqual(SentryDataCategory(name: "replay"), .replay)
        XCTAssertEqual(SentryDataCategory(name: "feedback"), .feedback)
        XCTAssertEqual(SentryDataCategory(name: "span"), .span)
        XCTAssertEqual(SentryDataCategory(name: "log_item"), .logItem)
        XCTAssertEqual(SentryDataCategory(name: "log_byte"), .logByte)
        XCTAssertEqual(SentryDataCategory(name: "trace_metric"), .traceMetric)
        XCTAssertEqual(SentryDataCategory(name: "trace_metric_byte"), .traceMetricByte)
        XCTAssertEqual(SentryDataCategory(name: "unknown"), .unknown)

        XCTAssertEqual(.unknown, SentryDataCategory(name: "gdfagdfsa"), "Failed to map unknown category name to case .unknown")
    }

    func testMapCategoryToString() {
        XCTAssertEqual(SentryDataCategory.all.name, "")
        XCTAssertEqual(SentryDataCategory.default.name, "default")
        XCTAssertEqual(SentryDataCategory.error.name, "error")
        XCTAssertEqual(SentryDataCategory.session.name, "session")
        XCTAssertEqual(SentryDataCategory.transaction.name, "transaction")
        XCTAssertEqual(SentryDataCategory.attachment.name, "attachment")
        XCTAssertEqual(SentryDataCategory.profile.name, "profile")
        XCTAssertEqual(SentryDataCategory.profileChunkUI.name, "profile_chunk_ui")
        XCTAssertEqual(SentryDataCategory.metricBucket.name, "metric_bucket")
        XCTAssertEqual(SentryDataCategory.replay.name, "replay")
        XCTAssertEqual(SentryDataCategory.feedback.name, "feedback")
        XCTAssertEqual(SentryDataCategory.span.name, "span")
        XCTAssertEqual(SentryDataCategory.logItem.name, "log_item")
        XCTAssertEqual(SentryDataCategory.logByte.name, "log_byte")
        XCTAssertEqual(SentryDataCategory.traceMetric.name, "trace_metric")
        XCTAssertEqual(SentryDataCategory.traceMetricByte.name, "trace_metric_byte")
        XCTAssertEqual(SentryDataCategory.unknown.name, "unknown")
    }
}
