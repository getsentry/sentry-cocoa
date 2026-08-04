@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

class SentryEnvelopeItemHeaderTests: XCTestCase {

    func test_SentryEnvelopeItemHeaderSerialization_DefaultInit() {
        // -- Arrange --
        let header = SentryEnvelopeItemHeader(type: "SomeType", length: 10)

        // -- Act --
        let data = header.serialize()

        // -- Assert --
        XCTAssertEqual(data["type"] as? String, "SomeType")
        XCTAssertEqual(data["length"] as? Int, 10)
        XCTAssertNil(data["filename"])
        XCTAssertNil(data["content_type"])
        XCTAssertEqual(data.count, 2)
    }

    func test_SentryEnvelopeItemHeaderSerialization_WithContentType() {
        // -- Arrange --
        let header = SentryEnvelopeItemHeader(type: "SomeType", length: 10, contentType: "text/html")

        // -- Act --
        let data = header.serialize()

        // -- Assert --
        XCTAssertEqual(data["type"] as? String, "SomeType")
        XCTAssertEqual(data["length"] as? Int, 10)
        XCTAssertNil(data["filename"])
        XCTAssertEqual(data["content_type"] as? String, "text/html")
        XCTAssertEqual(data.count, 3)
    }

    func test_SentryEnvelopeItemHeaderSerialization_WithItemCount() {
        // -- Arrange --
        let header = SentryEnvelopeItemHeader(type: "SomeType", length: 10, contentType: "text/html", itemCount: NSNumber(value: 3))

        // -- Act --
        let data = header.serialize()

        // -- Assert --
        XCTAssertEqual(data["type"] as? String, "SomeType")
        XCTAssertEqual(data["length"] as? Int, 10)
        XCTAssertNil(data["filename"])
        XCTAssertEqual(data["content_type"] as? String, "text/html")
        XCTAssertEqual(data["item_count"] as? NSNumber, NSNumber(value: 3))
        XCTAssertEqual(data.count, 4)
    }

    func test_SentryEnvelopeItemHeaderSerialization_WithFilename() {
        // -- Arrange --
        let header = SentryEnvelopeItemHeader(type: "SomeType", length: 10, filename: "SomeFileName", contentType: "text/html")

        // -- Act --
        let data = header.serialize()

        // -- Assert --
        XCTAssertEqual(data["type"] as? String, "SomeType")
        XCTAssertEqual(data["length"] as? Int, 10)
        XCTAssertEqual(data["filename"] as? String, "SomeFileName")
        XCTAssertEqual(data["content_type"] as? String, "text/html")
        XCTAssertEqual(data.count, 4)
    }

    // Regression test for the platform item header being dropped from profile-chunk
    // envelopes: serialize used to write contentType (nil here) under the "platform"
    // key, so setValue:nil removed it. Found while investigating
    // https://github.com/getsentry/sentry-cocoa/issues/8174
    func test_SentryEnvelopeItemHeaderSerialization_WithPlatform() {
        // -- Arrange --
        let header = SentryEnvelopeItemHeader(type: "SomeType", length: 10)
        header.platform = "cocoa"

        // -- Act --
        let data = header.serialize()

        // -- Assert --
        XCTAssertEqual(data["type"] as? String, "SomeType")
        XCTAssertEqual(data["length"] as? Int, 10)
        XCTAssertNil(data["content_type"])
        XCTAssertEqual(data["platform"] as? String, "cocoa")
        XCTAssertEqual(data.count, 3)
    }

    func testInit_whenOnlyTypeAndLength_shouldLeaveRemainingPropertiesNil() {
        // -- Arrange & Act --
        let header = SentryEnvelopeItemHeader(type: "SomeType", length: 10)

        // -- Assert --
        XCTAssertEqual(header.type, "SomeType")
        XCTAssertEqual(header.length, 10)
        XCTAssertNil(header.filename)
        XCTAssertNil(header.contentType)
        XCTAssertNil(header.itemCount)
        XCTAssertNil(header.platform)
    }

    func testInit_whenFilenameAndContentTypeGiven_shouldExposeThemAsProperties() {
        // -- Arrange --
        let header = SentryEnvelopeItemHeader(type: "SomeType", length: 10, filename: "SomeFileName", contentType: "text/html")

        // -- Act --
        header.platform = "cocoa"

        // -- Assert --
        XCTAssertEqual(header.type, "SomeType")
        XCTAssertEqual(header.length, 10)
        XCTAssertEqual(header.filename, "SomeFileName")
        XCTAssertEqual(header.contentType, "text/html")
        XCTAssertEqual(header.platform, "cocoa")
    }

    func testInit_whenItemCountGiven_shouldExposeItemCountAndNoFilename() {
        // -- Arrange & Act --
        let header = SentryEnvelopeItemHeader(type: "SomeType", length: 10, contentType: "text/html", itemCount: NSNumber(value: 3))

        // -- Assert --
        XCTAssertEqual(header.contentType, "text/html")
        XCTAssertEqual(header.itemCount, NSNumber(value: 3))
        XCTAssertNil(header.filename)
    }

    /// The `contentType` parameter of the item-count initializer is nullable. Serializing must then
    /// omit `content_type` while still writing `item_count`.
    func testSerialize_whenContentTypeNilAndItemCountGiven_shouldOmitContentTypeOnly() {
        // -- Arrange --
        let header = SentryEnvelopeItemHeader(type: "SomeType", length: 10, contentType: nil, itemCount: NSNumber(value: 3))

        // -- Act --
        let data = header.serialize()

        // -- Assert --
        XCTAssertEqual(data["type"] as? String, "SomeType")
        XCTAssertEqual(data["length"] as? Int, 10)
        XCTAssertNil(data["content_type"])
        XCTAssertEqual(data["item_count"] as? NSNumber, NSNumber(value: 3))
        XCTAssertEqual(data.count, 3)
    }

    /// `length` is an unsigned integer. A large value must survive serialization without
    /// overflowing or being truncated to a signed type.
    func testSerialize_whenLengthExceedsInt32_shouldNotOverflow() {
        // -- Arrange --
        let header = SentryEnvelopeItemHeader(type: "SomeType", length: UInt(UInt32.max))

        // -- Act --
        let data = header.serialize()

        // -- Assert --
        XCTAssertEqual(data["length"] as? UInt, UInt(UInt32.max))
    }

    func testSerialize_whenLengthIsZero_shouldStillWriteLength() {
        // -- Arrange --
        let header = SentryEnvelopeItemHeader(type: "SomeType", length: 0)

        // -- Act --
        let data = header.serialize()

        // -- Assert --
        XCTAssertEqual(data["length"] as? Int, 0)
        XCTAssertEqual(data.count, 2)
    }

    /// Empty strings are not nil and must therefore still be serialized.
    func testSerialize_whenStringsAreEmpty_shouldStillWriteThem() {
        // -- Arrange --
        let header = SentryEnvelopeItemHeader(type: "", length: 10, filename: "", contentType: "")

        // -- Act --
        let data = header.serialize()

        // -- Assert --
        XCTAssertEqual(data["type"] as? String, "")
        XCTAssertEqual(data["filename"] as? String, "")
        XCTAssertEqual(data["content_type"] as? String, "")
        XCTAssertEqual(data.count, 4)
    }

    func testSerialize_whenPlatformResetToNil_shouldOmitPlatform() {
        // -- Arrange --
        let header = SentryEnvelopeItemHeader(type: "SomeType", length: 10)
        header.platform = "cocoa"
        header.platform = nil

        // -- Act --
        let data = header.serialize()

        // -- Assert --
        XCTAssertNil(data["platform"])
        XCTAssertEqual(data.count, 2)
    }

    func testInit_whenAttachmentTypeGiven_shouldExposeInheritedAndOwnProperties() {
        // -- Arrange & Act --
        let header = SentryEnvelopeAttachmentHeader(type: "SomeType", length: 10, filename: "SomeFileName", contentType: "SomeContentType", attachmentType: .viewHierarchy)

        // -- Assert --
        XCTAssertEqual(header.type, "SomeType")
        XCTAssertEqual(header.length, 10)
        XCTAssertEqual(header.filename, "SomeFileName")
        XCTAssertEqual(header.contentType, "SomeContentType")
        XCTAssertEqual(header.attachmentType, .viewHierarchy)
    }

    func testInit_whenAttachmentTypeOmitted_shouldDefaultToEventAttachment() {
        // -- Arrange & Act --
        let header = SentryEnvelopeAttachmentHeader(type: "SomeType", length: 10)

        // -- Assert --
        XCTAssertEqual(header.attachmentType, .eventAttachment)
    }

    /// The subclass must remain assignable to the base type, since `SentryEnvelopeItem.header`
    /// is typed as `SentryEnvelopeItemHeader` and deserialization branches on the concrete class.
    func testSerialize_whenAttachmentHeaderTypedAsItemHeader_shouldUseSubclassOverride() {
        // -- Arrange --
        let header: SentryEnvelopeItemHeader = SentryEnvelopeAttachmentHeader(type: "SomeType", length: 10)

        // -- Act --
        let data = header.serialize()

        // -- Assert --
        XCTAssertTrue(header is SentryEnvelopeAttachmentHeader)
        XCTAssertEqual(data["attachment_type"] as? String, "event.attachment")
    }

    /// The subclass inherits the mutable `platform` property and must serialize both its own
    /// `attachment_type` and the inherited keys.
    func testSerialize_whenAttachmentHeaderHasPlatform_shouldWritePlatformAndAttachmentType() {
        // -- Arrange --
        let header = SentryEnvelopeAttachmentHeader(type: "SomeType", length: 10)
        header.platform = "cocoa"

        // -- Act --
        let data = header.serialize()

        // -- Assert --
        XCTAssertEqual(data["platform"] as? String, "cocoa")
        XCTAssertEqual(data["attachment_type"] as? String, "event.attachment")
        XCTAssertEqual(data.count, 4)
    }
}
