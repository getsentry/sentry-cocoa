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
#import "SentryOptionsInternal.h"
#import "SentrySDK+Private.h"
#import <SentryBreadcrumb+Private.h>
#import <XCTest/XCTest.h>
@import Sentry;

@interface SentryBreadcrumbTracker ()

+ (NSString *)sanitizeViewControllerName:(NSString *)controller;

@end

@interface SentryTests : XCTestCase

@end

@implementation SentryTests

- (void)setUp
{
    [SentrySDKInternal.currentHub bindClient:nil];
}

- (void)testSharedClient
{
    NSError *error = nil;
    SentryOptions *options = [SentryOptionsInternal
            initWithDict:@{ @"dsn" : @"https://username:password@app.getsentry.com/12345" }
        didFailWithError:&error];

    SentryClient *client = [[SentryClient alloc] initWithOptions:options];
    XCTAssertNil(error);
    XCTAssertNil([SentrySDKInternal.currentHub getClient]);
    [SentrySDKInternal.currentHub bindClient:client];
    XCTAssertNotNil([SentrySDKInternal.currentHub getClient]);
    [SentrySDKInternal.currentHub bindClient:nil];
}

- (void)testSDKDefaultHub
{
    [SentrySDK startWithConfigureOptions:^(SentryOptions *_Nonnull options) {
        options.dsn = @"https://username:password@app.getsentry.com/12345";
    }];
    XCTAssertNotNil([SentrySDKInternal.currentHub getClient]);
    [SentrySDKInternal.currentHub bindClient:nil];
}

- (void)testSDKBreadCrumbAdd
{
    [SentrySDK startWithConfigureOptions:^(SentryOptions *_Nonnull options) {
        options.dsn = @"https://username:password@app.getsentry.com/12345";
    }];

    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                                             category:@"testCategory"];
    crumb.type = @"testType";
    crumb.origin = @"testOrigin";
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

- (void)testToIso8601StringNil_ReturnsNil
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    NSString *dateAsString = sentry_toIso8601String(nil);
#pragma clang diagnostic pop
    XCTAssertNil(dateAsString);
}

@end
