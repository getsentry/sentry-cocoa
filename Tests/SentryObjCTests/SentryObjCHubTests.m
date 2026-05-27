@import SentryObjC;
@import XCTest;

@interface SentryObjCHubTests : XCTestCase
@property (nonatomic, strong) SentryObjCHub *sut;
@end

@implementation SentryObjCHubTests

- (void)setUp
{
    [super setUp];
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];
    options.dsn = @"https://key@sentry.io/123";
    options.enableCrashHandler = NO;
    SentryObjCClient *client = [[SentryObjCClient alloc] initWithOptions:options];
    self.sut = [[SentryObjCHub alloc] initWithClient:client
                                            andScope:[[SentryObjCScope alloc] init]];
}

- (void)tearDown
{
    [self.sut close];
    self.sut = nil;
    [super tearDown];
}

#pragma mark - Init

- (void)testInit_whenNilClientAndScope_shouldCreateHub
{
    // -- Arrange & Act --
    SentryObjCHub *hub = [[SentryObjCHub alloc] initWithClient:nil andScope:nil];

    // -- Assert --
    XCTAssertNotNil(hub);
}

- (void)testInit_whenClientProvided_shouldCreateHub
{
    // -- Assert --
    XCTAssertNotNil(self.sut);
}

#pragma mark - Sessions

- (void)testStartSession_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [self.sut startSession];
}

- (void)testEndSession_shouldNotCrash
{
    // -- Arrange --
    [self.sut startSession];

    // -- Act & Assert (no crash) --
    [self.sut endSession];
}

- (void)testEndSessionWithTimestamp_shouldNotCrash
{
    // -- Arrange --
    [self.sut startSession];

    // -- Act & Assert (no crash) --
    [self.sut endSessionWithTimestamp:[NSDate date]];
}

#pragma mark - Capture Event

- (void)testCaptureEvent_shouldReturnNonEmptyId
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Act --
    SentryObjCId *eventId = [self.sut captureEvent:event];

    // -- Assert --
    XCTAssertNotNil(eventId);
    XCTAssertEqual(eventId.sentryIdString.length, 32U);
    XCTAssertNotEqualObjects(eventId.sentryIdString, SentryObjCId.empty.sentryIdString);
}

- (void)testCaptureEventWithScope_shouldReturnNonEmptyId
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];
    [scope setTagValue:@"val" forKey:@"key"];

    // -- Act --
    SentryObjCId *eventId = [self.sut captureEvent:event withScope:scope];

    // -- Assert --
    XCTAssertNotNil(eventId);
    XCTAssertEqual(eventId.sentryIdString.length, 32U);
    XCTAssertNotEqualObjects(eventId.sentryIdString, SentryObjCId.empty.sentryIdString);
}

#pragma mark - Capture Error

- (void)testCaptureError_shouldReturnNonEmptyId
{
    // -- Arrange --
    NSError *error = [NSError errorWithDomain:@"test" code:1 userInfo:nil];

    // -- Act --
    SentryObjCId *eventId = [self.sut captureError:error];

    // -- Assert --
    XCTAssertNotNil(eventId);
    XCTAssertEqual(eventId.sentryIdString.length, 32U);
    XCTAssertNotEqualObjects(eventId.sentryIdString, SentryObjCId.empty.sentryIdString);
}

- (void)testCaptureErrorWithScope_shouldReturnNonEmptyId
{
    // -- Arrange --
    NSError *error = [NSError errorWithDomain:@"test" code:1 userInfo:nil];
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act --
    SentryObjCId *eventId = [self.sut captureError:error withScope:scope];

    // -- Assert --
    XCTAssertNotNil(eventId);
    XCTAssertEqual(eventId.sentryIdString.length, 32U);
    XCTAssertNotEqualObjects(eventId.sentryIdString, SentryObjCId.empty.sentryIdString);
}

#pragma mark - Capture Exception

- (void)testCaptureException_shouldReturnNonEmptyId
{
    // -- Arrange --
    NSException *exception = [NSException exceptionWithName:NSGenericException
                                                     reason:@"test"
                                                   userInfo:nil];

    // -- Act --
    SentryObjCId *eventId = [self.sut captureException:exception];

    // -- Assert --
    XCTAssertNotNil(eventId);
    XCTAssertEqual(eventId.sentryIdString.length, 32U);
    XCTAssertNotEqualObjects(eventId.sentryIdString, SentryObjCId.empty.sentryIdString);
}

- (void)testCaptureExceptionWithScope_shouldReturnNonEmptyId
{
    // -- Arrange --
    NSException *exception = [NSException exceptionWithName:NSGenericException
                                                     reason:@"test"
                                                   userInfo:nil];
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act --
    SentryObjCId *eventId = [self.sut captureException:exception withScope:scope];

    // -- Assert --
    XCTAssertNotNil(eventId);
    XCTAssertEqual(eventId.sentryIdString.length, 32U);
    XCTAssertNotEqualObjects(eventId.sentryIdString, SentryObjCId.empty.sentryIdString);
}

#pragma mark - Capture Message

- (void)testCaptureMessage_shouldReturnNonEmptyId
{
    // -- Act --
    SentryObjCId *eventId = [self.sut captureMessage:@"hello"];

    // -- Assert --
    XCTAssertNotNil(eventId);
    XCTAssertEqual(eventId.sentryIdString.length, 32U);
    XCTAssertNotEqualObjects(eventId.sentryIdString, SentryObjCId.empty.sentryIdString);
}

- (void)testCaptureMessageWithScope_shouldReturnNonEmptyId
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act --
    SentryObjCId *eventId = [self.sut captureMessage:@"hello" withScope:scope];

    // -- Assert --
    XCTAssertNotNil(eventId);
    XCTAssertEqual(eventId.sentryIdString.length, 32U);
    XCTAssertNotEqualObjects(eventId.sentryIdString, SentryObjCId.empty.sentryIdString);
}

#pragma mark - Capture Feedback

- (void)testCaptureFeedback_shouldNotCrash
{
    // -- Arrange --
    SentryObjCFeedback *feedback =
        [[SentryObjCFeedback alloc] initWithMessage:@"test"
                                               name:nil
                                              email:nil
                                             source:SentryObjCFeedbackSourceCustom
                                  associatedEventId:nil
                                        attachments:nil];

    // -- Act & Assert (no crash) --
    [self.sut captureFeedback:feedback];
}

#pragma mark - Transactions

- (void)testStartTransaction_shouldReturnSpanWithCorrectOperation
{
    // -- Act --
    SentryObjCSpan *span = [self.sut startTransactionWithName:@"test" operation:@"op"];

    // -- Assert --
    XCTAssertNotNil(span);
    XCTAssertEqualObjects(span.operation, @"op");
}

- (void)testStartTransactionBindToScope_shouldReturnSpanWithCorrectOperation
{
    // -- Act --
    SentryObjCSpan *span = [self.sut startTransactionWithName:@"test"
                                                    operation:@"op"
                                                  bindToScope:YES];

    // -- Assert --
    XCTAssertNotNil(span);
    XCTAssertEqualObjects(span.operation, @"op");
}

- (void)testStartTransactionWithContext_shouldReturnSpanWithCorrectOperation
{
    // -- Arrange --
    SentryObjCTransactionContext *context =
        [[SentryObjCTransactionContext alloc] initWithName:@"test" operation:@"op"];

    // -- Act --
    SentryObjCSpan *span = [self.sut startTransactionWithContext:context];

    // -- Assert --
    XCTAssertNotNil(span);
    XCTAssertEqualObjects(span.operation, @"op");
}

- (void)testStartTransactionWithContextBindToScope_shouldReturnSpanWithCorrectOperation
{
    // -- Arrange --
    SentryObjCTransactionContext *context =
        [[SentryObjCTransactionContext alloc] initWithName:@"test" operation:@"op"];

    // -- Act --
    SentryObjCSpan *span = [self.sut startTransactionWithContext:context bindToScope:YES];

    // -- Assert --
    XCTAssertNotNil(span);
    XCTAssertEqualObjects(span.operation, @"op");
}

- (void)
    testStartTransactionWithContextBindToScopeCustomSampling_shouldReturnSpanWithCorrectOperation
{
    // -- Arrange --
    SentryObjCTransactionContext *context =
        [[SentryObjCTransactionContext alloc] initWithName:@"test" operation:@"op"];
    NSDictionary *customSamplingContext = @{ @"key" : @"value" };

    // -- Act --
    SentryObjCSpan *span = [self.sut startTransactionWithContext:context
                                                     bindToScope:YES
                                           customSamplingContext:customSamplingContext];

    // -- Assert --
    XCTAssertNotNil(span);
    XCTAssertEqualObjects(span.operation, @"op");
}

- (void)testStartTransactionWithContextCustomSampling_shouldReturnSpanWithCorrectOperation
{
    // -- Arrange --
    SentryObjCTransactionContext *context =
        [[SentryObjCTransactionContext alloc] initWithName:@"test" operation:@"op"];
    NSDictionary *customSamplingContext = @{ @"key" : @"value" };

    // -- Act --
    SentryObjCSpan *span = [self.sut startTransactionWithContext:context
                                           customSamplingContext:customSamplingContext];

    // -- Assert --
    XCTAssertNotNil(span);
    XCTAssertEqualObjects(span.operation, @"op");
}

#pragma mark - Configure Scope

- (void)testConfigureScope_shouldPersistTagChanges
{
    // -- Act --
    [self.sut configureScope:^(
        SentryObjCScope *scope) { [scope setTagValue:@"test-value" forKey:@"test-key"]; }];

    // -- Assert --
    XCTAssertEqualObjects(self.sut.scope.tags[@"test-key"], @"test-value");
}

#pragma mark - Breadcrumbs

- (void)testAddBreadcrumb_shouldNotCrash
{
    // -- Arrange --
    SentryObjCBreadcrumb *crumb = [[SentryObjCBreadcrumb alloc] initWithLevel:SentryObjCLevelInfo
                                                                     category:@"test"];

    // -- Act & Assert (no crash) --
    [self.sut addBreadcrumb:crumb];
}

#pragma mark - Client

- (void)testGetClient_whenClientSet_shouldReturnEnabledClient
{
    // -- Act --
    SentryObjCClient *client = [self.sut getClient];

    // -- Assert --
    XCTAssertNotNil(client);
    XCTAssertTrue(client.isEnabled);
}

- (void)testGetClient_whenNilClient_shouldReturnNil
{
    // -- Arrange --
    SentryObjCHub *hub = [[SentryObjCHub alloc] initWithClient:nil andScope:nil];

    // -- Act --
    SentryObjCClient *client = [hub getClient];

    // -- Assert --
    XCTAssertNil(client);
}

#pragma mark - Scope

- (void)testScope_shouldReturnUsableScope
{
    // -- Act --
    SentryObjCScope *scope = self.sut.scope;

    // -- Assert --
    XCTAssertNotNil(scope);
    [scope setTagValue:@"value" forKey:@"key"];
    XCTAssertEqualObjects(scope.tags[@"key"], @"value");
}

#pragma mark - Bind Client

- (void)testBindClient_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [self.sut bindClient:nil];
}

#pragma mark - Integrations

- (void)testHasIntegration_whenUnknownName_shouldReturnNo
{
    // -- Act --
    BOOL result = [self.sut hasIntegration:@"NonExistentIntegration"];

    // -- Assert --
    XCTAssertFalse(result);
}

- (void)testIsIntegrationInstalled_whenUnrelatedClass_shouldReturnNo
{
    // -- Act --
    BOOL result = [self.sut isIntegrationInstalled:[NSObject class]];

    // -- Assert --
    XCTAssertFalse(result);
}

#pragma mark - User

- (void)testSetUser_shouldNotCrash
{
    // -- Arrange --
    SentryObjCUser *user = [[SentryObjCUser alloc] initWithUserId:@"u1"];

    // -- Act & Assert (no crash) --
    [self.sut setUser:user];
}

- (void)testSetUserNil_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [self.sut setUser:nil];
}

#pragma mark - Misc

- (void)testReportFullyDisplayed_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [self.sut reportFullyDisplayed];
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
