//
//  SentryOptionsTest.m
//  SentryTests
//
//  Created by Daniel Griesser on 12.03.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SentryError.h"
#import "SentryOptions.h"
#import "SentrySDK.h"

@interface SentryOptionsTest : XCTestCase

@end

@implementation SentryOptionsTest

- (void)testEmptyDsn {
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{} didFailWithError:&error];

    [self assertDisabled:options andError:error];
}

- (void)testInvalidDsnBoolean {
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{@"dsn": @YES} didFailWithError:&error];
    
    [self assertDisabled:options andError:error];
}

-(void)assertDisabled: (SentryOptions*) options
               andError: (NSError*) error {
    XCTAssertNil(options.dsn);
    XCTAssertEqual(@NO, options.enabled);
    XCTAssertEqual(@NO, options.debug);
    XCTAssertNil(error);
}

- (void)testInvalidDsn {
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{@"dsn": @"https://sentry.io"} didFailWithError:&error];
    XCTAssertEqual(kSentryErrorInvalidDsnError, error.code);
    XCTAssertNil(options);
}
    
- (void)testRelease {
    SentryOptions *options = [self getValidOptions:@{}];
    XCTAssertNil(options.releaseName);
    
    options = [self getValidOptions:@{@"release": @"abc"}];
    XCTAssertEqualObjects(options.releaseName, @"abc");
}
    
- (void)testEnvironment {
    SentryOptions *options = [self getValidOptions:@{}];
    XCTAssertNil(options.environment);
    
    options = [self getValidOptions:@{@"environment": @"xxx"}];
    XCTAssertEqualObjects(options.environment, @"xxx");
}

- (void)testDist {
    SentryOptions *options = [self getValidOptions:@{}];
    XCTAssertNil(options.dist);
    
    options = [self getValidOptions:@{@"dist": @"hhh"}];
    XCTAssertEqualObjects(options.dist, @"hhh");
}

-(void)testValidDebug {
    [self testDebugWith:@YES expected:@YES expectedLogLevel:kSentryLogLevelDebug];
    [self testDebugWith:@"YES" expected:@YES expectedLogLevel:kSentryLogLevelDebug];
}

-(void)testInvalidDebug {
    [self testDebugWith:@"Invalid" expected:@NO expectedLogLevel:kSentryLogLevelError];
    [self testDebugWith:@NO expected:@NO expectedLogLevel:kSentryLogLevelError];
}

-(void)testDebugWith: (NSObject*) debugValue
        expected: (NSNumber*) expectedDebugValue
    expectedLogLevel: (SentryLogLevel) expectedLogLevel {
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{@"debug": debugValue} didFailWithError:&error];
    
    
    XCTAssertNil(error);
    XCTAssertEqual(expectedDebugValue, options.debug);
    XCTAssertEqual(expectedLogLevel, SentrySDK.logLevel);
}

-(void)testDebugWithVerbose {
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc]
                              initWithDict:@{@"debug": @YES, @"logLevel": @"verbose"}
                              didFailWithError:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(@YES, options.debug);
    // TODO (bruno-garcia) I guess we want it to be verbose.
    XCTAssertEqual(kSentryLogLevelDebug, SentrySDK.logLevel);
}

-(void)testValidEnabled {
    [self testEnabledWith:@YES expected:@YES];
    [self testEnabledWith:@"YES" expected:@YES];
}

-(void)testInvalidEnabled {
    [self testEnabledWith:@"Invalid" expected:@NO];
    [self testEnabledWith:@NO expected:@NO];
}

-(void)testEnabledWith: (NSObject*) enabledValue
              expected:(NSNumber*) expectedValue {
    SentryOptions *options = [self getValidOptions: @{@"enabled": enabledValue}];
                    
    XCTAssertEqual(expectedValue, options.enabled);
}

-(void)testMaxBreadCrumbs {
    NSNumber* maxBreadCrumbs = @20;
    
    SentryOptions *options = [self getValidOptions: @{@"maxBreadcrumbs": maxBreadCrumbs}];
    
    XCTAssertEqual([maxBreadCrumbs unsignedIntValue], options.maxBreadcrumbs);
}

-(void)testMaxBreadCrumbsFallback {
    SentryOptions *options = [self getValidOptions:@{}];
    
    XCTAssertEqual([@100 unsignedIntValue], options.maxBreadcrumbs);
}

-(void)testBeforeSend {
    SentryEvent* (^callback) (SentryEvent* event) = ^(SentryEvent* event) {
        return event;
    };
    SentryOptions *options = [self getValidOptions:@{@"beforeSend": callback}];
    
    XCTAssertEqual(callback, options.beforeSend);
}

-(void)testBeforeSendIsEmpty {
    SentryOptions *options = [self getValidOptions:@{}];
    
    XCTAssertNil(options.beforeSend);
}

-(SentryOptions *) getValidOptions:(NSDictionary<NSString *, id> *) dict {
    NSError *error = nil;
    
    NSMutableDictionary<NSString *, id>* options = [[NSMutableDictionary alloc] init];
    options[@"dsn"] = @"https://username:password@sentry.io/1";
    
    [options addEntriesFromDictionary:dict];
    
    SentryOptions *sentryOptions = [[SentryOptions alloc]
                              initWithDict:options
                              didFailWithError:&error];
    XCTAssertNil(error);
    return sentryOptions;
}

@end
