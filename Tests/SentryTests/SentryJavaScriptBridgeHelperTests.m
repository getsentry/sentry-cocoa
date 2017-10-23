//
//  SentryJavaScriptBridgeHelperTests.m
//  SentryTests
//
//  Created by Daniel Griesser on 23.10.17.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SentryJavaScriptBridgeHelper.h"
#import <Sentry/Sentry.h>

@interface SentryJavaScriptBridgeHelper()

+ (NSArray *)parseJavaScriptStacktrace:(NSString *)stacktrace;
+ (NSArray *)parseRavenFrames:(NSArray *)ravenFrames;
+ (NSArray<SentryFrame *> *)convertReactNativeStacktrace:(NSArray *)stacktrace;
+ (void)addExceptionToEvent:(SentryEvent *)event type:(NSString *)type value:(NSString *)value frames:(NSArray *)frames;
+ (SentrySeverity)sentrySeverityFromLevel:(NSString *)level;
+ (NSDictionary *)sanitizeDictionary:(NSDictionary *)dictionary;

@end

@interface SentryJavaScriptBridgeHelperTests : XCTestCase

@end

@implementation SentryJavaScriptBridgeHelperTests

//+ (SentryEvent *)createSentryEventFromJavaScriptEvent:(NSDictionary *)jsonEvent;
//
//+ (SentryBreadcrumb *)createSentryBreadcrumbFromJavaScriptBreadcrumb:(NSDictionary *)jsonBreadcrumb;
//
//+ (NSArray *)parseJavaScriptStacktrace:(NSString *)stacktrace;
//
//+ (NSArray *)parseRavenFrames:(NSArray *)ravenFrames;
//
//+ (NSArray<SentryFrame *> *)convertReactNativeStacktrace:(NSArray *)stacktrace;
//
//+ (void)addExceptionToEvent:(SentryEvent *)event type:(NSString *)type value:(NSString *)value frames:(NSArray *)frames;
//
//+ (SentryUser *_Nullable)createUser:(NSDictionary *)user;
//
//+ (NSDictionary *)sanitizeDictionary:(NSDictionary *)dictionary;

- (void)testSentrySeverityFromLevel {
    XCTAssertEqual([SentryJavaScriptBridgeHelper sentrySeverityFromLevel:nil], kSentrySeverityError);
    XCTAssertEqual([SentryJavaScriptBridgeHelper sentrySeverityFromLevel:@"log"], kSentrySeverityInfo);
    XCTAssertEqual([SentryJavaScriptBridgeHelper sentrySeverityFromLevel:@"info"], kSentrySeverityInfo);
    XCTAssertEqual([SentryJavaScriptBridgeHelper sentrySeverityFromLevel:@"bla"], kSentrySeverityError);
    XCTAssertEqual([SentryJavaScriptBridgeHelper sentrySeverityFromLevel:@"fatal"], kSentrySeverityFatal);
    XCTAssertEqual([SentryJavaScriptBridgeHelper sentrySeverityFromLevel:@"debug"], kSentrySeverityDebug);
    XCTAssertEqual([SentryJavaScriptBridgeHelper sentrySeverityFromLevel:@"warning"], kSentrySeverityWarning);
}

- (void)

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
