#import "NSDate+SentryExtras.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryMessage.h"
#import "SentryMeta.h"
#import <Sentry/Sentry.h>
#import <XCTest/XCTest.h>

@interface SentryBreadcrumbTracker (Private)

+ (NSString *)sanitizeViewControllerName:(NSString *)controller;

@end

@interface SentryTests : XCTestCase

@end

@implementation SentryTests

- (void)testVersion
{
    NSDictionary *info = [[NSBundle bundleForClass:[SentryClient class]] infoDictionary];
    NSString *version = [NSString stringWithFormat:@"%@", info[@"CFBundleShortVersionString"]];
    if ([info[@"CFBundleIdentifier"] isEqualToString:@"io.sentry.Sentry"]) {
        // This test is running on a bundle that is not the SDK
        // (code was loaded inside an app for example)
        // in this case, we don't care about asserting our hard coded value matches
        // since this will be the app version instead of our SDK version.
        XCTAssert([version isEqualToString:SentryMeta.versionString]);
    }
}

- (void)testSharedClient
{
    NSError *error = nil;
    // SentryClient.logLevel = kSentryLogLevelNone;
    SentryOptions *options = [[SentryOptions alloc]
            initWithDict:@{ @"dsn" : @"https://username:password@app.getsentry.com/12345" }
        didFailWithError:&error];

    SentryClient *client = [[SentryClient alloc] initWithOptions:options];
    XCTAssertNil(error);
    XCTAssertNil([SentrySDK.currentHub getClient]);
    [SentrySDK.currentHub bindClient:client];
    XCTAssertNotNil([SentrySDK.currentHub getClient]);
    [SentrySDK.currentHub bindClient:nil];
}

- (void)testSDKDefaultHub
{
    [SentrySDK startWithOptions:@{ @"dsn" : @"https://username:password@app.getsentry.com/12345" }];
    XCTAssertNotNil([SentrySDK.currentHub getClient]);
    [SentrySDK.currentHub bindClient:nil];
    //[SentrySDK.currentHub reset];
}

// TODO(fetzig) write new test for custom hub
//- (void)testSDKCustomHub {
//    NSError *error = nil;
//    SentryClient.logLevel = kSentryLogLevelNone;
//    SentryClient *client = [[SentryClient alloc]
//    initWithDsn:@"https://username:password@app.getsentry.com/12345"
//    didFailWithError:&error];
//
//    SentryHub * hub = [[SentryHub alloc] init
//    XCTAssertNotNil(hub);
//    XCTAssertNotNil(SentryClient.sharedClient);
//    [SentryHub.defaultHub reset];
//    XCTAssertNil(SentryClient.sharedClient);
//    hub = nil;
//    XCTAssertNil(hub);
//}

// TODO
//- (void)testCrash {
//    NSError *error = nil;
//    SentryClient *client = [[SentryClient alloc]
//    initWithDsn:@"https://username:password@app.getsentry.com/12345"
//    didFailWithError:&error]; [client crash];
//}

// TODO
//- (void)testCrashedLastLaunch {
//    NSError *error = nil;
//    SentryClient *client = [[SentryClient alloc]
//    initWithDsn:@"https://username:password@app.getsentry.com/12345"
//    didFailWithError:&error]; XCTAssertFalse([client crashedLastLaunch]);
//}

//- (void)testBreadCrumbTracking {
//    NSError *error = nil;
//    SentryClient *client = [[SentryClient alloc]
//    initWithDsn:@"https://username:password@app.getsentry.com/123456"
//    didFailWithError:&error]; SentryScope *scope = [SentryScope new];
//
//    [scope.breadcrumbs clear];
//    [SentrySDK enableAutomaticBreadcrumbTracking];
//    XCTAssertEqual(scope.breadcrumbs.count, (unsigned long)0);
//
//    [SentrySDK.currentHub bindClient:client];
//    [SentrySDK enableAutomaticBreadcrumbTracking];
//    [SentrySDK.currentHub configureScope:^(SentryScope * _Nonnull scope) {
//
//        // TEST(fetzig): either this requires some XCT-ansync magic, or use
//        something else than configureScope
//        XCTAssertEqual(scope.breadcrumbs.count, (unsigned long)1);
//    }];
//    [SentrySDK.currentHub bindClient:nil];
//    [scope.breadcrumbs clear];
//}

//- (void)testSDKBreadCrumbTracking {
//    [SentrySDK startWithOptionsDict:@{@"dsn":
//    @"https://username:password@app.getsentry.com/12345"}];
//    [SentrySDK.currentHub configureScope:^(SentryScope * _Nonnull scope) {
//
//        [scope.breadcrumbs clear];
//        // TEST(fetzig): either this requires some XCT-ansync magic, or use
//        something else than configureScope
//        XCTAssertEqual(scope.breadcrumbs.count, (unsigned long)1);
//    }];
//
//    [SentrySDK enableAutomaticBreadcrumbTracking];
//    [SentrySDK.currentHub configureScope:^(SentryScope * _Nonnull scope) {
//        // TEST(fetzig): either this requires some XCT-ansync magic, or use
//        something else than configureScope
//        XCTAssertEqual(scope.breadcrumbs.count, (unsigned long)1);
//    }];
//
//    // [SentrySDK.currentHub reset];
//}

- (void)testSDKBreadCrumbAdd
{
    [SentrySDK startWithOptions:@{ @"dsn" : @"https://username:password@app.getsentry.com/12345" }];

    // TODO(fetzig)
    //[[SentrySDK.currentHub getClient].breadcrumbs clear];

    // XCTAssertEqual([SentryHub.defaultHub getClient].breadcrumbs.count,
    // (unsigned long)0);

    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                                             category:@"testCategory"];
    crumb.type = @"testType";
    crumb.message = @"testMessage";
    crumb.data = @{ @"testDataKey" : @"testDataVaue" };

    [SentrySDK addBreadcrumb:crumb];

    // XCTAssertEqual([SentryHub.defaultHub getClient].breadcrumbs.count,
    // (unsigned long)1);
    // TODO(fetzig)
    //[[SentrySDK.currentHub getClient].breadcrumbs clear];

    //[SentrySDK.currentHub reset];
}

- (void)testSDKCaptureEvent
{
    [SentrySDK startWithOptions:@{ @"dsn" : @"https://username:password@app.getsentry.com/12345" }];

    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelFatal];

    event.timestamp = [NSDate date];
    event.message = [[SentryMessage alloc] initWithFormatted:@"testy test"];

    [SentrySDK captureEvent:event];

    // TODO(fetzig)
    //[SentrySDK.currentHub reset];
}

- (void)testSDKCaptureError
{
    [SentrySDK startWithOptions:@{ @"dsn" : @"https://username:password@app.getsentry.com/12345" }];

    NSError *error =
        [NSError errorWithDomain:@"testworld"
                            code:200
                        userInfo:@{ NSLocalizedDescriptionKey : @"test ran out of money" }];
    [SentrySDK captureError:error];

    // TODO(fetzig)
    //[SentrySDK.currentHub reset];
}

//- (void)testSDKCaptureException {
//    [SentrySDK startWithOptionsDict:@{@"dsn":
//    @"https://username:password@app.getsentry.com/12345"}];
//    XCTAssertNotNil([SentrySDK.currentHub getClient]);
//    @try{
//        @throw [[NSException alloc] initWithName:@"test" reason:@"Testing"
//        userInfo:nil];
//    }
//    @catch(NSException *e){
//        [SentrySDK captureException:e];
//        // TODO(fetzig): check if we can add some assertion to this
//        //[SentrySDK.currentHub reset];
//    }
//    XCTAssertNil([SentrySDK.currentHub getClient]);
//}

//- (void)testSDKCaptureMessage {
//    [SentrySDK startWithOptionsDict:@{@"dsn":
//    @"https://username:password@app.getsentry.com/12345"}];
//    XCTAssertNotNil([SentrySDK.currentHub getClient]);
//    [SentrySDK captureMessage:@"test message"];
//    // TODO(fetzig)
//    //[SentryHub.defaultHub reset];
//    XCTAssertNil([SentrySDK.currentHub getClient]);
//}

//- (void)testUserException {
//    NSError *error = nil;
//    SentryClient *client = [[SentryClient alloc]
//    initWithDsn:@"https://username:password@app.getsentry.com/12345"
//    didFailWithError:&error]; [client reportUserException:@"a" reason:@"b"
//    language:@"c" lineOfCode:@"1" stackTrace:[NSArray new] logAllThreads:YES
//    terminateProgram:NO];
//}

- (void)testLevelNames
{
    XCTAssertEqualObjects(@"none", SentryLevelNames[kSentryLevelNone]);
    XCTAssertEqualObjects(@"debug", SentryLevelNames[kSentryLevelDebug]);
    XCTAssertEqualObjects(@"info", SentryLevelNames[kSentryLevelInfo]);
    XCTAssertEqualObjects(@"warning", SentryLevelNames[kSentryLevelWarning]);
    XCTAssertEqualObjects(@"error", SentryLevelNames[kSentryLevelError]);
    XCTAssertEqualObjects(@"fatal", SentryLevelNames[kSentryLevelFatal]);
}

- (void)testLevelOrder
{
    XCTAssertGreaterThan(kSentryLevelFatal, kSentryLevelError);
    XCTAssertGreaterThan(kSentryLevelError, kSentryLevelWarning);
    XCTAssertGreaterThan(kSentryLevelWarning, kSentryLevelInfo);
    XCTAssertGreaterThan(kSentryLevelInfo, kSentryLevelDebug);
    XCTAssertGreaterThan(kSentryLevelDebug, kSentryLevelNone);
}

- (void)testDateCategory
{
    NSDate *date = [NSDate date];
    XCTAssertEqual(
        (NSInteger)[
            [NSDate sentry_fromIso8601String:[date sentry_toIso8601String]] timeIntervalSince1970],
        (NSInteger)[date timeIntervalSince1970]);
}

- (void)testBreadcrumbTracker
{
    XCTAssertEqualObjects(@"sentry_ios_cocoapods.ViewController",
        [SentryBreadcrumbTracker
            sanitizeViewControllerName:@"<sentry_ios_cocoapods.ViewController: 0x7fd9201253c0>"]);
    XCTAssertEqualObjects(@"sentry_ios_cocoapodsViewController: 0x7fd9201253c0",
        [SentryBreadcrumbTracker
            sanitizeViewControllerName:@"sentry_ios_cocoapodsViewController: 0x7fd9201253c0"]);
    XCTAssertEqualObjects(@"sentry_ios_cocoapods.ViewController.miau",
        [SentryBreadcrumbTracker
            sanitizeViewControllerName:
                @"<sentry_ios_cocoapods.ViewController.miau: 0x7fd9201253c0>"]);
}

@end
