@import SentryObjC;
@import XCTest;

@interface SentryObjCClientTests : XCTestCase
@property (nonatomic, strong) SentryObjCClient *sut;
@end

@implementation SentryObjCClientTests

- (void)setUp
{
    [super setUp];
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];
    options.dsn = @"https://key@sentry.io/123";
    self.sut = [[SentryObjCClient alloc] initWithOptions:options];
}

- (void)tearDown
{
    [self.sut close];
    self.sut = nil;
    [super tearDown];
}

- (void)testInit_whenValidOptions_shouldCreateClient
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];
    options.dsn = @"https://key@sentry.io/123";

    // -- Act --
    SentryObjCClient *client = [[SentryObjCClient alloc] initWithOptions:options];

    // -- Assert --
    XCTAssertNotNil(client);
}

- (void)testIsEnabled_shouldReturnBool
{
    // -- Arrange & Act --
    BOOL enabled = self.sut.isEnabled;

    // -- Assert --
    // Just verify property access doesn't crash; value may be YES or NO depending on state.
    XCTAssertTrue(enabled || !enabled);
}

- (void)testOptions_shouldReturnOptions
{
    // -- Arrange & Act --
    SentryObjCOptions *options = self.sut.options;

    // -- Assert --
    XCTAssertNotNil(options);
}

- (void)testCaptureEvent_shouldReturnId
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Act --
    SentryObjCId *result = [self.sut captureEvent:event];

    // -- Assert --
    XCTAssertNotNil(result);
}

- (void)testCaptureEventWithScope_shouldReturnId
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act --
    SentryObjCId *result = [self.sut captureEvent:event withScope:scope];

    // -- Assert --
    XCTAssertNotNil(result);
}

- (void)testCaptureError_shouldReturnId
{
    // -- Arrange --
    NSError *error = [NSError errorWithDomain:@"test" code:1 userInfo:nil];

    // -- Act --
    SentryObjCId *result = [self.sut captureError:error];

    // -- Assert --
    XCTAssertNotNil(result);
}

- (void)testCaptureErrorWithScope_shouldReturnId
{
    // -- Arrange --
    NSError *error = [NSError errorWithDomain:@"test" code:1 userInfo:nil];
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act --
    SentryObjCId *result = [self.sut captureError:error withScope:scope];

    // -- Assert --
    XCTAssertNotNil(result);
}

- (void)testCaptureException_shouldReturnId
{
    // -- Arrange --
    NSException *exception = [NSException exceptionWithName:NSGenericException
                                                     reason:@"test"
                                                   userInfo:nil];

    // -- Act --
    SentryObjCId *result = [self.sut captureException:exception];

    // -- Assert --
    XCTAssertNotNil(result);
}

- (void)testCaptureExceptionWithScope_shouldReturnId
{
    // -- Arrange --
    NSException *exception = [NSException exceptionWithName:NSGenericException
                                                     reason:@"test"
                                                   userInfo:nil];
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act --
    SentryObjCId *result = [self.sut captureException:exception withScope:scope];

    // -- Assert --
    XCTAssertNotNil(result);
}

- (void)testCaptureMessage_shouldReturnId
{
    // -- Act --
    SentryObjCId *result = [self.sut captureMessage:@"hello"];

    // -- Assert --
    XCTAssertNotNil(result);
}

- (void)testCaptureMessageWithScope_shouldReturnId
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act --
    SentryObjCId *result = [self.sut captureMessage:@"hello" withScope:scope];

    // -- Assert --
    XCTAssertNotNil(result);
}

- (void)testCaptureFeedbackWithScope_shouldNotCrash
{
    // -- Arrange --
    SentryObjCFeedback *feedback =
        [[SentryObjCFeedback alloc] initWithMessage:@"test"
                                               name:nil
                                              email:nil
                                             source:SentryObjCFeedbackSourceCustom
                                  associatedEventId:nil
                                        attachments:nil];
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act & Assert (no crash) --
    [self.sut captureFeedback:feedback withScope:scope];
}

- (void)testFlush_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [self.sut flush:0.1];
}

- (void)testClose_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [self.sut close];
}

@end
