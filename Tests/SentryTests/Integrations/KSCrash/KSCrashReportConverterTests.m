#import "KSCrashReportConverter.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentrySwift.h"
#import <XCTest/XCTest.h>
@import Sentry;

@interface KSCrashReportConverterTests : XCTestCase
@end

@implementation KSCrashReportConverterTests

- (NSDictionary *)nsexceptionReport
{
    return @{
        @"report" : @ { @"timestamp" : @"2024-01-01T00:00:00Z" },
        @"crash" : @ {
            @"error" : @ {
                @"type" : @"nsexception",
                @"reason" : @"something went wrong",
                @"nsexception" : @ { @"name" : @"NSInvalidArgumentException" }
            },
            @"threads" : @[ @{
                @"index" : @0,
                @"crashed" : @YES,
                @"backtrace" : @ { @"contents" : @[ @{ @"instruction_addr" : @(0xdeadbeef) } ] },
                @"registers" : @ { @"basic" : @ { } }
            } ]
        },
        @"binary_images" : @[],
        @"user" : @ {
            @"sentry_sdk_scope" : @ {
                @"release" : @"1.0",
                @"environment" : @"production",
                @"tags" : @ { @"key" : @"value" }
            }
        },
        @"system" : @ { @"application_stats" : @ { @"application_in_foreground" : @YES } }
    };
}

- (void)test_nsexception_setsExceptionType
{
    SentryInAppLogic *logic = [[SentryInAppLogic alloc] initWithInAppIncludes:@[]];
    KSCrashReportConverter *sut =
        [[KSCrashReportConverter alloc] initWithReport:[self nsexceptionReport] inAppLogic:logic];
    SentryEvent *event = [sut convertReportToEvent];
    XCTAssertEqualObjects(event.exceptions.firstObject.type, @"NSInvalidArgumentException");
}

- (void)test_nsexception_setsEnvironmentFromScope
{
    SentryInAppLogic *logic = [[SentryInAppLogic alloc] initWithInAppIncludes:@[]];
    KSCrashReportConverter *sut =
        [[KSCrashReportConverter alloc] initWithReport:[self nsexceptionReport] inAppLogic:logic];
    SentryEvent *event = [sut convertReportToEvent];
    XCTAssertEqualObjects(event.environment, @"production");
}

- (void)test_nsexception_setsTagsFromScope
{
    SentryInAppLogic *logic = [[SentryInAppLogic alloc] initWithInAppIncludes:@[]];
    KSCrashReportConverter *sut =
        [[KSCrashReportConverter alloc] initWithReport:[self nsexceptionReport] inAppLogic:logic];
    SentryEvent *event = [sut convertReportToEvent];
    XCTAssertEqualObjects(event.tags[@"key"], @"value");
}

- (void)test_scopeIsInsideUser_notTopLevel
{
    // Verify the converter reads sentry_sdk_scope from the user field (not top-level).
    // A report WITHOUT user.sentry_sdk_scope should have nil environment.
    NSDictionary *reportWithoutScope = @{
        @"report" : @ { @"timestamp" : @"2024-01-01T00:00:00Z" },
        @"crash" : @ {
            @"error" : @ {
                @"type" : @"nsexception",
                @"reason" : @"x",
                @"nsexception" : @ { @"name" : @"NSException" }
            },
            @"threads" : @[]
        },
        @"binary_images" : @[],
        @"system" : @ { @"application_stats" : @ { @"application_in_foreground" : @YES } }
    };
    SentryInAppLogic *logic = [[SentryInAppLogic alloc] initWithInAppIncludes:@[]];
    KSCrashReportConverter *sut = [[KSCrashReportConverter alloc] initWithReport:reportWithoutScope
                                                                      inAppLogic:logic];
    SentryEvent *event = [sut convertReportToEvent];
    XCTAssertNil(event.environment);
}

@end
