//
//  SentryTests.m
//  SentryTests
//
//  Created by Daniel Griesser on 02/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Sentry/Sentry.h>
#import "SentryKSCrashInstallation.h"

@interface SentryTests : XCTestCase

@end

@implementation SentryTests

- (void)testVersion {
    NSDictionary *info = [[NSBundle bundleForClass:[SentryClient class]] infoDictionary];
    NSString *version = [NSString stringWithFormat:@"%@", info[@"CFBundleShortVersionString"]];
    XCTAssert([version isEqualToString:SentryClient.versionString]);
}

- (void)testStartCrashHandler {
    NSError *error = nil;
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345" didFailWithError:&error];
    XCTAssertNil(error);
    XCTAssertFalse([client startCrashHandlerWithError:&error]);
    XCTAssertNotNil(error);
}

- (void)testSharedClient {
    NSError *error = nil;
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345" didFailWithError:&error];
    XCTAssertNil(error);
    XCTAssertNil(SentryClient.sharedClient);
    SentryClient.sharedClient = client;
    XCTAssertNotNil(SentryClient.sharedClient);
}

- (void)testCrash {
    NSError *error = nil;
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345" didFailWithError:&error];
    [client crash];
}

- (void)testInstallation {
    SentryKSCrashInstallation *installation = [[SentryKSCrashInstallation alloc] init];
    [installation sendAllReports];
}

- (void)testUserException {
    NSError *error = nil;
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345" didFailWithError:&error];
    [client reportUserException:@"a" reason:@"b" language:@"c" lineOfCode:@"1" stackTrace:@[] logAllThreads:YES terminateProgram:NO];
}

- (void)testSeverity {
    XCTAssertEqualObjects(@"fatal", SentrySeverityNames[kSentrySeverityFatal]);
    XCTAssertEqualObjects(@"error", SentrySeverityNames[kSentrySeverityError]);
    XCTAssertEqualObjects(@"warning", SentrySeverityNames[kSentrySeverityWarning]);
    XCTAssertEqualObjects(@"info", SentrySeverityNames[kSentrySeverityInfo]);
    XCTAssertEqualObjects(@"debug", SentrySeverityNames[kSentrySeverityDebug]);
}

@end
