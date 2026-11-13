@import SentryObjC;
@import XCTest;

#if SENTRY_OBJC_WEBVIEW_SUPPORTED
@import WebKit;

static NSString *const kTestDSN = @"https://key@sentry.io/123";

@interface SentryObjCWebViewTracingTests : XCTestCase
@end

@implementation SentryObjCWebViewTracingTests

- (void)setUp
{
    [super setUp];
    [SentryObjCSDK startWithConfigureOptions:^(SentryObjCOptions *options) {
        options.dsn = kTestDSN;
        options.enableCrashHandler = NO;
    }];
}

- (void)tearDown
{
    [SentryObjCSDK close];
    [super tearDown];
}

- (SentryObjCWebViewTracingOptions *)options
{
    return [[SentryObjCWebViewTracingOptions alloc] initWithAllowedHosts:@[ @"example.com" ]];
}

- (void)testAddTracePropagation_shouldAddScriptAtDocumentStart
{
    // -- Arrange --
    WKUserContentController *controller = [[WKUserContentController alloc] init];

    // -- Act --
    BOOL installed =
        [SentryObjCWebViewTracing addTracePropagationToUserContentController:controller
                                                                     options:[self options]];

    // -- Assert --
    XCTAssertTrue(installed);
    XCTAssertEqual(controller.userScripts.count, 1);
    WKUserScript *script = controller.userScripts.firstObject;
    XCTAssertEqual(script.injectionTime, WKUserScriptInjectionTimeAtDocumentStart);
    XCTAssertTrue(script.isForMainFrameOnly);
    XCTAssertTrue([script.source containsString:@"example.com"]);
}

- (void)testAddTracePropagation_whenCalledTwice_shouldKeepOneScript
{
    // -- Arrange --
    WKUserContentController *controller = [[WKUserContentController alloc] init];
    [SentryObjCWebViewTracing addTracePropagationToUserContentController:controller
                                                                 options:[self options]];

    // -- Act --
    [SentryObjCWebViewTracing addTracePropagationToUserContentController:controller
                                                                 options:[self options]];

    // -- Assert --
    XCTAssertEqual(controller.userScripts.count, 1);
}

- (void)testAddTracePropagation_whenConfiguration_shouldAddScriptToItsController
{
    // -- Arrange --
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];

    // -- Act --
    BOOL installed = [SentryObjCWebViewTracing addTracePropagationToConfiguration:configuration
                                                                          options:[self options]];

    // -- Assert --
    XCTAssertTrue(installed);
    XCTAssertEqual(configuration.userContentController.userScripts.count, 1);
}

- (void)testAddTracePropagation_whenWebView_shouldAddScriptToItsController
{
    // -- Arrange --
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero
                                            configuration:[[WKWebViewConfiguration alloc] init]];

    // -- Act --
    BOOL installed = [SentryObjCWebViewTracing addTracePropagationToWebView:webView
                                                                    options:[self options]];

    // -- Assert --
    XCTAssertTrue(installed);
    XCTAssertEqual(webView.configuration.userContentController.userScripts.count, 1);
}

- (void)testAddTracePropagation_whenOffMainThread_shouldReturnNo
{
    // -- Arrange --
    WKUserContentController *controller = [[WKUserContentController alloc] init];
    SentryObjCWebViewTracingOptions *options = [self options];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Called off main thread"];
    __block BOOL installed = YES;

    // -- Act --
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        installed = [SentryObjCWebViewTracing addTracePropagationToUserContentController:controller
                                                                                 options:options];
        [expectation fulfill];
    });
    [self waitForExpectations:@[ expectation ] timeout:5];

    // -- Assert --
    XCTAssertFalse(installed);
    XCTAssertEqual(controller.userScripts.count, 0);
}

- (void)testAddTracePropagation_whenSDKClosed_shouldNotAddScript
{
    // -- Arrange --
    [SentryObjCSDK close];
    WKUserContentController *controller = [[WKUserContentController alloc] init];

    // -- Act --
    BOOL installed =
        [SentryObjCWebViewTracing addTracePropagationToUserContentController:controller
                                                                     options:[self options]];

    // -- Assert --
    XCTAssertFalse(installed);
    XCTAssertEqual(controller.userScripts.count, 0);
}

- (void)testWebViewTracingOption_whenDefault_shouldBeNil
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Assert --
    XCTAssertNil(options.webViewTracing);
}

- (void)testWebViewTracingOption_whenSet_shouldReturnItsHosts
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.webViewTracing = [self options];

    // -- Assert --
    XCTAssertEqualObjects(options.webViewTracing.allowedHosts, @[ @"example.com" ]);
    options.webViewTracing = nil;
    XCTAssertNil(options.webViewTracing);
}

- (void)testWebViewTracingOption_whenSDKStarted_shouldAddScriptBeforeLoad
{
    // -- Arrange --
    [SentryObjCSDK close];
    [SentryObjCSDK startWithConfigureOptions:^(SentryObjCOptions *options) {
        options.dsn = kTestDSN;
        options.enableCrashHandler = NO;
        options.webViewTracing = [self options];
    }];
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero
                                            configuration:[[WKWebViewConfiguration alloc] init]];

    // -- Act --
    [webView loadHTMLString:@"" baseURL:[NSURL URLWithString:@"https://example.com/"]];

    // -- Assert --
    NSArray<WKUserScript *> *scripts = webView.configuration.userContentController.userScripts;
    XCTAssertEqual(scripts.count, 1);
    XCTAssertTrue([scripts.firstObject.source containsString:@"example.com"]);
}

@end

#endif
