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


@interface SentryOptionsTest : XCTestCase

@end

@implementation SentryOptionsTest


- (void)testEmptyDsn {
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{} didFailWithError:&error];
    
    // TODO(fetzig): not sure if this test needs an update or SentryOptions/SentryDsn needs a fix. Maybe the error should be set to kSentryErrorInvalidDsnError
    [self assertDidabled:options andError:error];
}

- (void)testInvalidDsnBoolean {
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{@"dsn": @YES} didFailWithError:&error];
    
    // TODO(fetzig): not sure if this test needs an update or SentryOptions/SentryDsn needs a fix. Maybe the error should be set to kSentryErrorInvalidDsnError
    [self assertDidabled:options andError:error];
}

-(void)assertDidabled: (SentryOptions*) options
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
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{@"dsn": @"https://username:password@sentry.io/1"} didFailWithError:&error];
    XCTAssertNil(error);
    XCTAssertNil(options.releaseName);
    
    options = [[SentryOptions alloc] initWithDict:@{@"dsn": @"https://username:password@sentry.io/1", @"release": @"abc"} didFailWithError:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(options.releaseName, @"abc");
}
    
- (void)testEnvironment {
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{@"dsn": @"https://username:password@sentry.io/1"} didFailWithError:&error];
    XCTAssertNil(error);
    XCTAssertNil(options.environment);
    
    options = [[SentryOptions alloc] initWithDict:@{@"dsn": @"https://username:password@sentry.io/1", @"environment": @"xxx"} didFailWithError:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(options.environment, @"xxx");
}

- (void)testDist {
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{@"dsn": @"https://username:password@sentry.io/1"} didFailWithError:&error];
    XCTAssertNil(error);
    XCTAssertNil(options.dist);
    
    options = [[SentryOptions alloc] initWithDict:@{@"dsn": @"https://username:password@sentry.io/1", @"dist": @"hhh"} didFailWithError:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(options.dist, @"hhh");
}

-(void)testValidDebug {
    [self testDebugWith:@YES expected:@YES];
    [self testDebugWith:@"YES" expected:@YES];
}

-(void)testInvalidDebug {
    [self testDebugWith:@"Invalid" expected:@NO];
    [self testDebugWith:@NO expected:@NO];
}

-(void)testDebugWith: (NSObject*) debugValue
        expected: (NSNumber*) expectedValue {
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{@"debug": debugValue} didFailWithError:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(expectedValue, options.debug);
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
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{
        @"dsn": @"https://username:password@sentry.io/1",
        @"enabled": enabledValue
    } didFailWithError:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(expectedValue, options.enabled);
}


@end
