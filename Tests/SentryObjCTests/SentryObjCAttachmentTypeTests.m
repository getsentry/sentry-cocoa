#import "SentryObjC.h"
@import XCTest;

@interface SentryObjCAttachmentTypeTests : XCTestCase
@end

@implementation SentryObjCAttachmentTypeTests

- (void)testAttachmentType_shouldMapAllCasesToExpectedValues
{
    // -- Assert --
    XCTAssertEqual(SentryObjCAttachmentTypeEventAttachment, (NSInteger)0);
    XCTAssertEqual(SentryObjCAttachmentTypeViewHierarchy, (NSInteger)1);
}

- (void)testAttachmentType_whenRoundTripped_shouldPreserveValue
{
    // -- Act --
    SentryObjCAttachmentType roundTripped
        = (SentryObjCAttachmentType)SentryObjCAttachmentTypeViewHierarchy;

    // -- Assert --
    XCTAssertEqual(roundTripped, SentryObjCAttachmentTypeViewHierarchy);
}

@end
