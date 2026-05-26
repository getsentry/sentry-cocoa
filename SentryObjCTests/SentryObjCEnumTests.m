@import SentryObjC;
@import XCTest;

@interface SentryObjCEnumTests : XCTestCase
@end

@implementation SentryObjCEnumTests

#pragma mark - SentryObjCLevel

- (void)testLevel_shouldMapAllCasesToExpectedValues
{
    // -- Assert --
    XCTAssertEqual(SentryObjCLevelNone, (NSUInteger)0);
    XCTAssertEqual(SentryObjCLevelDebug, (NSUInteger)1);
    XCTAssertEqual(SentryObjCLevelInfo, (NSUInteger)2);
    XCTAssertEqual(SentryObjCLevelWarning, (NSUInteger)3);
    XCTAssertEqual(SentryObjCLevelError, (NSUInteger)4);
    XCTAssertEqual(SentryObjCLevelFatal, (NSUInteger)5);
}

- (void)testLevel_whenRoundTripped_shouldPreserveValue
{
    // -- Act --
    SentryObjCLevel roundTripped = (SentryObjCLevel)SentryObjCLevelWarning;

    // -- Assert --
    XCTAssertEqual(roundTripped, SentryObjCLevelWarning);
}

#pragma mark - SentryObjCSpanStatus

- (void)testSpanStatus_shouldMapAllCasesToExpectedValues
{
    // -- Assert --
    XCTAssertEqual(SentryObjCSpanStatusUndefined, (NSUInteger)0);
    XCTAssertEqual(SentryObjCSpanStatusOk, (NSUInteger)1);
    XCTAssertEqual(SentryObjCSpanStatusDeadlineExceeded, (NSUInteger)2);
    XCTAssertEqual(SentryObjCSpanStatusUnauthenticated, (NSUInteger)3);
    XCTAssertEqual(SentryObjCSpanStatusPermissionDenied, (NSUInteger)4);
    XCTAssertEqual(SentryObjCSpanStatusNotFound, (NSUInteger)5);
    XCTAssertEqual(SentryObjCSpanStatusResourceExhausted, (NSUInteger)6);
    XCTAssertEqual(SentryObjCSpanStatusInvalidArgument, (NSUInteger)7);
    XCTAssertEqual(SentryObjCSpanStatusUnimplemented, (NSUInteger)8);
    XCTAssertEqual(SentryObjCSpanStatusUnavailable, (NSUInteger)9);
    XCTAssertEqual(SentryObjCSpanStatusInternalError, (NSUInteger)10);
    XCTAssertEqual(SentryObjCSpanStatusUnknownError, (NSUInteger)11);
    XCTAssertEqual(SentryObjCSpanStatusCancelled, (NSUInteger)12);
    XCTAssertEqual(SentryObjCSpanStatusAlreadyExists, (NSUInteger)13);
    XCTAssertEqual(SentryObjCSpanStatusFailedPrecondition, (NSUInteger)14);
    XCTAssertEqual(SentryObjCSpanStatusAborted, (NSUInteger)15);
    XCTAssertEqual(SentryObjCSpanStatusOutOfRange, (NSUInteger)16);
    XCTAssertEqual(SentryObjCSpanStatusDataLoss, (NSUInteger)17);
}

- (void)testSpanStatus_whenRoundTripped_shouldPreserveValue
{
    // -- Act --
    SentryObjCSpanStatus roundTripped = (SentryObjCSpanStatus)SentryObjCSpanStatusOk;

    // -- Assert --
    XCTAssertEqual(roundTripped, SentryObjCSpanStatusOk);
}

#pragma mark - SentryObjCSampleDecision

- (void)testSampleDecision_shouldMapAllCasesToExpectedValues
{
    // -- Assert --
    XCTAssertEqual(SentryObjCSampleDecisionUndecided, (NSUInteger)0);
    XCTAssertEqual(SentryObjCSampleDecisionYes, (NSUInteger)1);
    XCTAssertEqual(SentryObjCSampleDecisionNo, (NSUInteger)2);
}

- (void)testSampleDecision_whenRoundTripped_shouldPreserveValue
{
    // -- Act --
    SentryObjCSampleDecision roundTripped = (SentryObjCSampleDecision)SentryObjCSampleDecisionNo;

    // -- Assert --
    XCTAssertEqual(roundTripped, SentryObjCSampleDecisionNo);
}

#pragma mark - SentryObjCTransactionNameSource

- (void)testTransactionNameSource_shouldMapAllCasesToExpectedValues
{
    // -- Assert --
    XCTAssertEqual(SentryObjCTransactionNameSourceCustom, (NSInteger)0);
    XCTAssertEqual(SentryObjCTransactionNameSourceUrl, (NSInteger)1);
    XCTAssertEqual(SentryObjCTransactionNameSourceRoute, (NSInteger)2);
    XCTAssertEqual(SentryObjCTransactionNameSourceView, (NSInteger)3);
    XCTAssertEqual(SentryObjCTransactionNameSourceComponent, (NSInteger)4);
    XCTAssertEqual(SentryObjCTransactionNameSourceTask, (NSInteger)5);
}

- (void)testTransactionNameSource_whenRoundTripped_shouldPreserveValue
{
    // -- Act --
    SentryObjCTransactionNameSource roundTripped
        = (SentryObjCTransactionNameSource)SentryObjCTransactionNameSourceRoute;

    // -- Assert --
    XCTAssertEqual(roundTripped, SentryObjCTransactionNameSourceRoute);
}

#pragma mark - SentryObjCAttachmentType

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

#pragma mark - SentryObjCFeedbackSource

- (void)testFeedbackSource_shouldMapAllCasesToExpectedValues
{
    // -- Assert --
    XCTAssertEqual(SentryObjCFeedbackSourceWidget, (NSInteger)0);
    XCTAssertEqual(SentryObjCFeedbackSourceCustom, (NSInteger)1);
}

- (void)testFeedbackSource_whenRoundTripped_shouldPreserveValue
{
    // -- Act --
    SentryObjCFeedbackSource roundTripped
        = (SentryObjCFeedbackSource)SentryObjCFeedbackSourceCustom;

    // -- Assert --
    XCTAssertEqual(roundTripped, SentryObjCFeedbackSourceCustom);
}

#pragma mark - SentryObjCLastRunStatus

- (void)testLastRunStatus_shouldMapAllCasesToExpectedValues
{
    // -- Assert --
    XCTAssertEqual(SentryObjCLastRunStatusUnknown, (NSInteger)0);
    XCTAssertEqual(SentryObjCLastRunStatusDidNotCrash, (NSInteger)1);
    XCTAssertEqual(SentryObjCLastRunStatusDidCrash, (NSInteger)2);
}

- (void)testLastRunStatus_whenRoundTripped_shouldPreserveValue
{
    // -- Act --
    SentryObjCLastRunStatus roundTripped = (SentryObjCLastRunStatus)SentryObjCLastRunStatusDidCrash;

    // -- Assert --
    XCTAssertEqual(roundTripped, SentryObjCLastRunStatusDidCrash);
}

#pragma mark - SentryObjCLogLevel

- (void)testLogLevel_shouldMapAllCasesToExpectedValues
{
    // -- Assert --
    XCTAssertEqual(SentryObjCLogLevelTrace, (NSInteger)0);
    XCTAssertEqual(SentryObjCLogLevelDebug, (NSInteger)1);
    XCTAssertEqual(SentryObjCLogLevelInfo, (NSInteger)2);
    XCTAssertEqual(SentryObjCLogLevelWarn, (NSInteger)3);
    XCTAssertEqual(SentryObjCLogLevelError, (NSInteger)4);
    XCTAssertEqual(SentryObjCLogLevelFatal, (NSInteger)5);
}

- (void)testLogLevel_whenRoundTripped_shouldPreserveValue
{
    // -- Act --
    SentryObjCLogLevel roundTripped = (SentryObjCLogLevel)SentryObjCLogLevelWarn;

    // -- Assert --
    XCTAssertEqual(roundTripped, SentryObjCLogLevelWarn);
}

#pragma mark - SentryObjCReplayQuality

- (void)testReplayQuality_shouldMapAllCasesToExpectedValues
{
    // -- Assert --
    XCTAssertEqual(SentryObjCReplayQualityLow, (NSInteger)0);
    XCTAssertEqual(SentryObjCReplayQualityMedium, (NSInteger)1);
    XCTAssertEqual(SentryObjCReplayQualityHigh, (NSInteger)2);
}

- (void)testReplayQuality_whenRoundTripped_shouldPreserveValue
{
    // -- Act --
    SentryObjCReplayQuality roundTripped = (SentryObjCReplayQuality)SentryObjCReplayQualityHigh;

    // -- Assert --
    XCTAssertEqual(roundTripped, SentryObjCReplayQualityHigh);
}

#pragma mark - SentryObjCRedactRegionType

- (void)testRedactRegionType_shouldMapAllCasesToExpectedValues
{
    // -- Assert --
    XCTAssertEqual(SentryObjCRedactRegionTypeRedact, (NSInteger)0);
    XCTAssertEqual(SentryObjCRedactRegionTypeClipOut, (NSInteger)1);
    XCTAssertEqual(SentryObjCRedactRegionTypeClipBegin, (NSInteger)2);
    XCTAssertEqual(SentryObjCRedactRegionTypeClipEnd, (NSInteger)3);
    XCTAssertEqual(SentryObjCRedactRegionTypeRedactSwiftUI, (NSInteger)4);
}

- (void)testRedactRegionType_whenRoundTripped_shouldPreserveValue
{
    // -- Act --
    SentryObjCRedactRegionType roundTripped
        = (SentryObjCRedactRegionType)SentryObjCRedactRegionTypeClipBegin;

    // -- Assert --
    XCTAssertEqual(roundTripped, SentryObjCRedactRegionTypeClipBegin);
}

@end
