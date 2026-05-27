#import "SentryObjC.h"
@import XCTest;

@interface SentryObjCFeedbackTests : XCTestCase
@end

@implementation SentryObjCFeedbackTests

#pragma mark - Init with all parameters

- (void)testInit_whenAllParameters_shouldSetMessage
{
    // -- Arrange --
    SentryObjCId *associatedId = [[SentryObjCId alloc] init];
    NSData *attachmentData = [@"screenshot" dataUsingEncoding:NSUTF8StringEncoding];
    SentryObjCAttachment *attachment =
        [[SentryObjCAttachment alloc] initWithData:attachmentData filename:@"screenshot.png"];

    // -- Act --
    SentryObjCFeedback *feedback =
        [[SentryObjCFeedback alloc] initWithMessage:@"App crashed"
                                               name:@"Test User"
                                              email:@"user@example.com"
                                             source:SentryObjCFeedbackSourceWidget
                                  associatedEventId:associatedId
                                        attachments:@[ attachment ]];

    // -- Assert --
    XCTAssertEqualObjects(feedback.message, @"App crashed");
}

- (void)testInit_whenAllParameters_shouldSetName
{
    // -- Arrange --
    SentryObjCId *associatedId = [[SentryObjCId alloc] init];
    NSData *attachmentData = [@"screenshot" dataUsingEncoding:NSUTF8StringEncoding];
    SentryObjCAttachment *attachment =
        [[SentryObjCAttachment alloc] initWithData:attachmentData filename:@"screenshot.png"];

    // -- Act --
    SentryObjCFeedback *feedback =
        [[SentryObjCFeedback alloc] initWithMessage:@"App crashed"
                                               name:@"Test User"
                                              email:@"user@example.com"
                                             source:SentryObjCFeedbackSourceWidget
                                  associatedEventId:associatedId
                                        attachments:@[ attachment ]];

    // -- Assert --
    XCTAssertEqualObjects(feedback.name, @"Test User");
}

- (void)testInit_whenAllParameters_shouldSetEmail
{
    // -- Arrange --
    SentryObjCId *associatedId = [[SentryObjCId alloc] init];
    NSData *attachmentData = [@"screenshot" dataUsingEncoding:NSUTF8StringEncoding];
    SentryObjCAttachment *attachment =
        [[SentryObjCAttachment alloc] initWithData:attachmentData filename:@"screenshot.png"];

    // -- Act --
    SentryObjCFeedback *feedback =
        [[SentryObjCFeedback alloc] initWithMessage:@"App crashed"
                                               name:@"Test User"
                                              email:@"user@example.com"
                                             source:SentryObjCFeedbackSourceWidget
                                  associatedEventId:associatedId
                                        attachments:@[ attachment ]];

    // -- Assert --
    XCTAssertEqualObjects(feedback.email, @"user@example.com");
}

- (void)testInit_whenAllParameters_shouldSetSource
{
    // -- Arrange --
    SentryObjCId *associatedId = [[SentryObjCId alloc] init];
    NSData *attachmentData = [@"screenshot" dataUsingEncoding:NSUTF8StringEncoding];
    SentryObjCAttachment *attachment =
        [[SentryObjCAttachment alloc] initWithData:attachmentData filename:@"screenshot.png"];

    // -- Act --
    SentryObjCFeedback *feedback =
        [[SentryObjCFeedback alloc] initWithMessage:@"App crashed"
                                               name:@"Test User"
                                              email:@"user@example.com"
                                             source:SentryObjCFeedbackSourceWidget
                                  associatedEventId:associatedId
                                        attachments:@[ attachment ]];

    // -- Assert --
    XCTAssertEqual(feedback.source, SentryObjCFeedbackSourceWidget);
}

- (void)testInit_whenAllParameters_shouldHaveEventId
{
    // -- Arrange --
    SentryObjCId *associatedId = [[SentryObjCId alloc] init];
    NSData *attachmentData = [@"screenshot" dataUsingEncoding:NSUTF8StringEncoding];
    SentryObjCAttachment *attachment =
        [[SentryObjCAttachment alloc] initWithData:attachmentData filename:@"screenshot.png"];

    // -- Act --
    SentryObjCFeedback *feedback =
        [[SentryObjCFeedback alloc] initWithMessage:@"App crashed"
                                               name:@"Test User"
                                              email:@"user@example.com"
                                             source:SentryObjCFeedbackSourceWidget
                                  associatedEventId:associatedId
                                        attachments:@[ attachment ]];

    // -- Assert --
    XCTAssertNotNil(feedback.eventId);
}

- (void)testInit_whenAllParameters_shouldSetAssociatedEventId
{
    // -- Arrange --
    SentryObjCId *associatedId = [[SentryObjCId alloc] init];
    NSData *attachmentData = [@"screenshot" dataUsingEncoding:NSUTF8StringEncoding];
    SentryObjCAttachment *attachment =
        [[SentryObjCAttachment alloc] initWithData:attachmentData filename:@"screenshot.png"];

    // -- Act --
    SentryObjCFeedback *feedback =
        [[SentryObjCFeedback alloc] initWithMessage:@"App crashed"
                                               name:@"Test User"
                                              email:@"user@example.com"
                                             source:SentryObjCFeedbackSourceWidget
                                  associatedEventId:associatedId
                                        attachments:@[ attachment ]];

    // -- Assert --
    XCTAssertNotNil(feedback.associatedEventId);
}

- (void)testInit_whenAllParameters_shouldSetAttachments
{
    // -- Arrange --
    SentryObjCId *associatedId = [[SentryObjCId alloc] init];
    NSData *attachmentData = [@"screenshot" dataUsingEncoding:NSUTF8StringEncoding];
    SentryObjCAttachment *attachment =
        [[SentryObjCAttachment alloc] initWithData:attachmentData filename:@"screenshot.png"];

    // -- Act --
    SentryObjCFeedback *feedback =
        [[SentryObjCFeedback alloc] initWithMessage:@"App crashed"
                                               name:@"Test User"
                                              email:@"user@example.com"
                                             source:SentryObjCFeedbackSourceWidget
                                  associatedEventId:associatedId
                                        attachments:@[ attachment ]];

    // -- Assert --
    XCTAssertNotNil(feedback.attachments);
    XCTAssertEqual(feedback.attachments.count, 1u);
}

#pragma mark - Init with nil optional parameters

- (void)testInit_whenNilName_shouldReturnNilName
{
    // -- Act --
    SentryObjCFeedback *feedback =
        [[SentryObjCFeedback alloc] initWithMessage:@"Feedback message"
                                               name:nil
                                              email:nil
                                             source:SentryObjCFeedbackSourceCustom
                                  associatedEventId:nil
                                        attachments:nil];

    // -- Assert --
    XCTAssertNil(feedback.name);
}

- (void)testInit_whenNilEmail_shouldReturnNilEmail
{
    // -- Act --
    SentryObjCFeedback *feedback =
        [[SentryObjCFeedback alloc] initWithMessage:@"Feedback message"
                                               name:nil
                                              email:nil
                                             source:SentryObjCFeedbackSourceCustom
                                  associatedEventId:nil
                                        attachments:nil];

    // -- Assert --
    XCTAssertNil(feedback.email);
}

- (void)testInit_whenNilOptionals_shouldSetMessageAndSource
{
    // -- Act --
    SentryObjCFeedback *feedback =
        [[SentryObjCFeedback alloc] initWithMessage:@"Feedback message"
                                               name:nil
                                              email:nil
                                             source:SentryObjCFeedbackSourceCustom
                                  associatedEventId:nil
                                        attachments:nil];

    // -- Assert --
    XCTAssertEqualObjects(feedback.message, @"Feedback message");
    XCTAssertEqual(feedback.source, SentryObjCFeedbackSourceCustom);
}

- (void)testInit_whenNilOptionals_shouldHaveEventId
{
    // -- Act --
    SentryObjCFeedback *feedback =
        [[SentryObjCFeedback alloc] initWithMessage:@"Feedback message"
                                               name:nil
                                              email:nil
                                             source:SentryObjCFeedbackSourceCustom
                                  associatedEventId:nil
                                        attachments:nil];

    // -- Assert --
    XCTAssertNotNil(feedback.eventId);
}

- (void)testInit_whenNilAssociatedEventId_shouldReturnNil
{
    // -- Act --
    SentryObjCFeedback *feedback =
        [[SentryObjCFeedback alloc] initWithMessage:@"Feedback message"
                                               name:nil
                                              email:nil
                                             source:SentryObjCFeedbackSourceCustom
                                  associatedEventId:nil
                                        attachments:nil];

    // -- Assert --
    XCTAssertNil(feedback.associatedEventId);
}

- (void)testInit_whenNilAttachments_shouldReturnNil
{
    // -- Act --
    SentryObjCFeedback *feedback =
        [[SentryObjCFeedback alloc] initWithMessage:@"Feedback message"
                                               name:nil
                                              email:nil
                                             source:SentryObjCFeedbackSourceCustom
                                  associatedEventId:nil
                                        attachments:nil];

    // -- Assert --
    XCTAssertNil(feedback.attachments);
}

@end
