//
//  SentryTests.m
//  SentryTests
//
//  Created by Daniel Griesser on 02/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Sentry/Sentry.h>
#import "SentryInstallation.h"
#import "NSDate+SentryExtras.h"

@interface SentryBreadcrumbTracker (Private)

+ (NSString *)sanitizeViewControllerName:(NSString *)controller;

@end

@interface SentryTests : XCTestCase

@end

@implementation SentryTests

- (void)testVersion {
    NSDictionary *info = [[NSBundle bundleForClass:[SentryClient class]] infoDictionary];
    NSString *version = [NSString stringWithFormat:@"%@", info[@"CFBundleShortVersionString"]];
    XCTAssert([version isEqualToString:SentryClient.versionString]);
}

- (void)testSharedClient {
    NSError *error = nil;
    SentryClient.logLevel = kSentryLogLevelNone;
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345" didFailWithError:&error];
    XCTAssertNil(error);
    XCTAssertNil(SentryClient.sharedClient);
    SentryClient.sharedClient = client;
    XCTAssertNotNil(SentryClient.sharedClient);
    [SentryClient setSharedClient:nil];
}

- (void)testSDKDefaultHub {
    [SentrySDK startWithOptions:@{@"dsn": @"https://username:password@app.getsentry.com/12345"}];
    XCTAssertNotNil(SentryClient.sharedClient);
    [SentryClient setSharedClient:nil];
    [SentryHub.defaultHub reset];
}

- (void)testSDKCustomHub {
    NSError *error = nil;
    SentryClient.logLevel = kSentryLogLevelNone;
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345" didFailWithError:&error];

    SentryHub * hub = [[SentryHub alloc] initWithClient:client];
    XCTAssertNotNil(hub);
    XCTAssertNotNil(SentryClient.sharedClient);
    [SentryHub.defaultHub reset];
    XCTAssertNil(SentryClient.sharedClient);
    hub = nil;
    XCTAssertNil(hub);
}

// TODO
//- (void)testCrash {
//    NSError *error = nil;
//    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345" didFailWithError:&error];
//    [client crash];
//}

// TODO
//- (void)testCrashedLastLaunch {
//    NSError *error = nil;
//    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345" didFailWithError:&error];
//    XCTAssertFalse([client crashedLastLaunch]);
//}

- (void)testBreadCrumbTracking {
    NSError *error = nil;
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/123456" didFailWithError:&error];
    [client.breadcrumbs clear];
    [client enableAutomaticBreadcrumbTracking];
    XCTAssertEqual(client.breadcrumbs.count, (unsigned long)0);
    [SentryClient setSharedClient:client];
    [SentryClient.sharedClient enableAutomaticBreadcrumbTracking];
    XCTAssertEqual(SentryClient.sharedClient.breadcrumbs.count, (unsigned long)1);
    [SentryClient setSharedClient:nil];
    [client.breadcrumbs clear];
}

- (void)testSDKBreadCrumbTracking {
    [SentrySDK startWithOptions:@{@"dsn": @"https://username:password@app.getsentry.com/12345"}];
    [[SentryHub.defaultHub getClient].breadcrumbs clear];
    [[SentryHub.defaultHub getClient] enableAutomaticBreadcrumbTracking];
    XCTAssertEqual([SentryHub.defaultHub getClient].breadcrumbs.count, (unsigned long)1);
    [[SentryHub.defaultHub getClient].breadcrumbs clear];
    [SentryHub.defaultHub reset];
}

- (void)testSDKBreadCrumbAdd {
    [SentrySDK startWithOptions:@{@"dsn": @"https://username:password@app.getsentry.com/12345"}];
    [[SentryHub.defaultHub getClient].breadcrumbs clear];

    XCTAssertEqual([SentryHub.defaultHub getClient].breadcrumbs.count, (unsigned long)0);

    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentrySeverityInfo category:@"testCategory"];
    crumb.type = @"testType";
    crumb.message = @"testMessage";
    crumb.data = @{@"testDataKey": @"testDataVaue"};

    [SentrySDK addBreadcrumb:crumb];

    XCTAssertEqual([SentryHub.defaultHub getClient].breadcrumbs.count, (unsigned long)1);
    [[SentryHub.defaultHub getClient].breadcrumbs clear];
    [SentryHub.defaultHub reset];
}

- (void)testSDKCaptureEvent {
    [SentrySDK startWithOptions:@{@"dsn": @"https://username:password@app.getsentry.com/12345"}];

    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityFatal];

    event.timestamp = [NSDate date];
    event.message = @"testy test";

    [SentrySDK captureEvent:event];

    [SentryHub.defaultHub reset];
}

- (void)testSDKCaptureError {
    [SentrySDK startWithOptions:@{@"dsn": @"https://username:password@app.getsentry.com/12345"}];

    NSError *error = [NSError errorWithDomain:@"testworld" code:200 userInfo:@{NSLocalizedDescriptionKey: @"test ran out of money"}];
    [SentrySDK captureError:error];

    [SentryHub.defaultHub reset];
}

- (void)testSDKCaptureException {
    [SentrySDK startWithOptions:@{@"dsn": @"https://username:password@app.getsentry.com/12345"}];
    XCTAssertNotNil(SentryClient.sharedClient);
    @try{
        @throw [[NSException alloc] initWithName:@"test" reason:@"Testing" userInfo:nil];
    }
    @catch(NSException *e){
        [SentrySDK captureException:e];
        // TODO(fetzig): check if we can add some assertion to this
        [SentryHub.defaultHub reset];
    }
    XCTAssertNil(SentryClient.sharedClient);
}

- (void)testSDKCaptureMessage {
    [SentrySDK startWithOptions:@{@"dsn": @"https://username:password@app.getsentry.com/12345"}];
    XCTAssertNotNil(SentryClient.sharedClient);
    [SentrySDK captureMessage:@"test message"];

    [SentryHub.defaultHub reset];
    XCTAssertNil(SentryClient.sharedClient);
}

- (void)testUserException {
    NSError *error = nil;
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345" didFailWithError:&error];
    [client reportUserException:@"a" reason:@"b" language:@"c" lineOfCode:@"1" stackTrace:[NSArray new] logAllThreads:YES terminateProgram:NO];
}

- (void)testSeverity {
    XCTAssertEqualObjects(@"fatal", SentrySeverityNames[kSentrySeverityFatal]);
    XCTAssertEqualObjects(@"error", SentrySeverityNames[kSentrySeverityError]);
    XCTAssertEqualObjects(@"warning", SentrySeverityNames[kSentrySeverityWarning]);
    XCTAssertEqualObjects(@"info", SentrySeverityNames[kSentrySeverityInfo]);
    XCTAssertEqualObjects(@"debug", SentrySeverityNames[kSentrySeverityDebug]);
}

- (void)testDateCategory {
    NSDate *date = [NSDate date];
    XCTAssertEqual((NSInteger)[[NSDate sentry_fromIso8601String:[date sentry_toIso8601String]] timeIntervalSince1970], (NSInteger)[date timeIntervalSince1970]);
}

- (void)testBreadcrumbTracker {
    XCTAssertEqualObjects(@"sentry_ios_cocoapods.ViewController", [SentryBreadcrumbTracker sanitizeViewControllerName:@"<sentry_ios_cocoapods.ViewController: 0x7fd9201253c0>"]);
    XCTAssertEqualObjects(@"sentry_ios_cocoapodsViewController: 0x7fd9201253c0", [SentryBreadcrumbTracker sanitizeViewControllerName:@"sentry_ios_cocoapodsViewController: 0x7fd9201253c0"]);
    XCTAssertEqualObjects(@"sentry_ios_cocoapods.ViewController.miau", [SentryBreadcrumbTracker sanitizeViewControllerName:@"<sentry_ios_cocoapods.ViewController.miau: 0x7fd9201253c0>"]);
}

@end
