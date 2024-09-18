#import "SentryBreadcrumb.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryClient.h"
#import "SentryDataCategory.h"
#import "SentryDateUtils.h"
#import "SentryEvent.h"
#import "SentryHub.h"
#import "SentryLevelMapper.h"
#import "SentryMessage.h"
#import "SentryMeta.h"
#import "SentryOptions+HybridSDKs.h"
#import "SentrySDK+Private.h"
#import <XCTest/XCTest.h>
@import Sentry;

@interface
SentryBreadcrumbTracker ()

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
        XCTAssert([version isEqualToString:SentryMeta.versionString],
            @"Version of bundle:%@ not equal to version of SentryMeta:%@", version,
            SentryMeta.versionString);
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
    [SentrySDK startWithConfigureOptions:^(SentryOptions *_Nonnull options) {
        options.dsn = @"https://username:password@app.getsentry.com/12345";
    }];
    XCTAssertNotNil([SentrySDK.currentHub getClient]);
    [SentrySDK.currentHub bindClient:nil];
}

- (void)testSDKBreadCrumbAdd
{
    [SentrySDK startWithConfigureOptions:^(SentryOptions *_Nonnull options) {
        options.dsn = @"https://username:password@app.getsentry.com/12345";
    }];

    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                                             category:@"testCategory"];
    crumb.type = @"testType";
    crumb.message = @"testMessage";
    crumb.data = @{ @"testDataKey" : @"testDataVaue" };

    [SentrySDK addBreadcrumb:crumb];
}

- (void)testSDKCaptureEvent
{
    [SentrySDK startWithConfigureOptions:^(SentryOptions *_Nonnull options) {
        options.dsn = @"https://username:password@app.getsentry.com/12345";
    }];

    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelFatal];

    event.timestamp = [NSDate date];
    event.message = [[SentryMessage alloc] initWithFormatted:@"testy test"];

    [SentrySDK captureEvent:event];
}

- (void)testSDKCaptureError
{
    [SentrySDK startWithConfigureOptions:^(SentryOptions *_Nonnull options) {
        options.dsn = @"https://username:password@app.getsentry.com/12345";
    }];

    NSError *error =
        [NSError errorWithDomain:@"testworld"
                            code:200
                        userInfo:@{ NSLocalizedDescriptionKey : @"test ran out of money" }];
    [SentrySDK captureError:error];
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
    XCTAssertEqual([sentry_fromIso8601String(sentry_toIso8601String(date)) timeIntervalSince1970],
        timeInterval);
}

- (void)testDateCategoryPrecision
{
    NSDate *date1 = [NSDate dateWithTimeIntervalSinceReferenceDate:0.1234];
    XCTAssertEqualObjects(sentry_toIso8601String(date1), @"2001-01-01T00:00:00.123Z");

    NSDate *date2 = [NSDate dateWithTimeIntervalSinceReferenceDate:0.9995];
    XCTAssertEqualObjects(sentry_toIso8601String(date2), @"2001-01-01T00:00:01.000Z");
}

- (void)testDateCategoryCompactibility
{
    NSDate *date = sentry_fromIso8601String(@"2020-02-27T11:35:26Z");
    XCTAssertEqual([date timeIntervalSince1970], 1582803326.0);
}

@end
