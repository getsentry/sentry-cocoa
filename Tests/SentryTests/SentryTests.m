#import "NSDate+SentryExtras.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryMessage.h"
#import "SentryMeta.h"
#import "SentrySDK+Private.h"
#import <Sentry/Sentry.h>
#import <XCTest/XCTest.h>

@interface SentryBreadcrumbTracker (Private)

+ (NSString *)sanitizeViewControllerName:(NSString *)controller;

@end

@interface SentryTests : XCTestCase

@end

@implementation SentryTests

- (void)setUp
{
    [SentrySDK.currentHub bindClient:nil];
}

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
}

- (void)testSDKBreadCrumbAdd
{
    [SentrySDK startWithOptions:@{ @"dsn" : @"https://username:password@app.getsentry.com/12345" }];

    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                                             category:@"testCategory"];
    crumb.type = @"testType";
    crumb.message = @"testMessage";
    crumb.data = @{ @"testDataKey" : @"testDataVaue" };

    [SentrySDK addBreadcrumb:crumb];
}

- (void)testSDKCaptureEvent
{
    [SentrySDK startWithOptions:@{ @"dsn" : @"https://username:password@app.getsentry.com/12345" }];

    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelFatal];

    event.timestamp = [NSDate date];
    event.message = [[SentryMessage alloc] initWithFormatted:@"testy test"];

    [SentrySDK captureEvent:event];
}

- (void)testSDKCaptureError
{
    [SentrySDK startWithOptions:@{ @"dsn" : @"https://username:password@app.getsentry.com/12345" }];

    NSError *error =
        [NSError errorWithDomain:@"testworld"
                            code:200
                        userInfo:@{ NSLocalizedDescriptionKey : @"test ran out of money" }];
    [SentrySDK captureError:error];
}

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
    NSTimeInterval timeInterval = 1605888590.123;
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timeInterval];
    XCTAssertEqual(
        [[NSDate sentry_fromIso8601String:[date sentry_toIso8601String]] timeIntervalSince1970],
        timeInterval);
}

- (void)testDateCategoryPrecision
{
    NSDate *date1 = [NSDate dateWithTimeIntervalSinceReferenceDate:0.1234];
    XCTAssertEqualObjects([date1 sentry_toIso8601String], @"2001-01-01T00:00:00.123Z");

    NSDate *date2 = [NSDate dateWithTimeIntervalSinceReferenceDate:0.9995];
    XCTAssertEqualObjects([date2 sentry_toIso8601String], @"2001-01-01T00:00:01.000Z");
}

- (void)testDateCategoryCompactibility
{
    NSDate *date = [NSDate sentry_fromIso8601String:@"2020-02-27T11:35:26Z"];
    XCTAssertEqual([date timeIntervalSince1970], 1582803326.0);
}

@end
