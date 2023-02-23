#import <Sentry/Sentry.h>
#import <XCTest/XCTest.h>

#import "NSDate+SentryExtras.h"
#import "SentryFileManager.h"
#import "SentryId.h"
#import "SentryMeta.h"

@interface SentryInterfacesTests : XCTestCase

@end

@implementation SentryInterfacesTests

// TODO test event

- (void)testFrame
{
    SentryFrame *frame = [[SentryFrame alloc] init];
    frame.symbolAddress = @"0x01";
    XCTAssertNotNil(frame.symbolAddress);
    NSDictionary *serialized = @{ @"symbol_addr" : @"0x01", @"function" : @"<redacted>" };
    XCTAssertEqualObjects([frame serialize], serialized);

    SentryFrame *frame2 = [[SentryFrame alloc] init];
    frame2.symbolAddress = @"0x01";
    XCTAssertNotNil(frame2.symbolAddress);

    frame2.fileName = @"file://b.swift";
    frame2.function = @"[hey2 alloc]";
    frame2.module = @"b";
    frame2.lineNumber = @(100);
    frame2.columnNumber = @(200);
    frame2.package = @"package";
    frame2.imageAddress = @"image_addr";
    frame2.instructionAddress = @"instruction_addr";
    frame2.symbolAddress = @"symbol_addr";
    frame2.platform = @"platform";
    NSDictionary *serialized2 = @{
        @"filename" : @"file://b.swift",
        @"function" : @"[hey2 alloc]",
        @"module" : @"b",
        @"package" : @"package",
        @"image_addr" : @"image_addr",
        @"instruction_addr" : @"instruction_addr",
        @"symbol_addr" : @"symbol_addr",
        @"platform" : @"platform",
        @"lineno" : @(100),
        @"colno" : @(200)
    };
    XCTAssertEqualObjects([frame2 serialize], serialized2);
}

- (void)testEvent
{
    NSDate *date = [NSDate date];
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelInfo];
    event.timestamp = date;
    event.environment = @"bla";
    event.sdk = @{ @"name" : @"sentry.cocoa", @"version" : SentryMeta.versionString };
    event.extra = @{ @"__sentry_stacktrace" : @"f", @"date" : date };
    NSDictionary *serialized = @{
        @"event_id" : [event.eventId sentryIdString],
        @"extra" : @ { @"date" : [date sentry_toIso8601String] },
        @"level" : @"info",
        @"environment" : @"bla",
        @"platform" : @"cocoa",
        @"sdk" : @ { @"name" : @"sentry.cocoa", @"version" : SentryMeta.versionString },
        @"timestamp" : @(date.timeIntervalSince1970)
    };
    XCTAssertEqualObjects([event serialize], serialized);

    SentryEvent *event2 = [[SentryEvent alloc] initWithLevel:kSentryLevelInfo];
    event2.timestamp = date;
    event2.sdk = @{ @"name" : @"sentry.cocoa", @"version" : SentryMeta.versionString };
    NSDictionary *serialized2 = @{
        @"event_id" : [event2.eventId sentryIdString],
        @"level" : @"info",
        @"platform" : @"cocoa",
        @"sdk" : @ { @"name" : @"sentry.cocoa", @"version" : SentryMeta.versionString },
        @"timestamp" : @(date.timeIntervalSince1970)
    };
    XCTAssertEqualObjects([event2 serialize], serialized2);

    SentryEvent *event3 = [[SentryEvent alloc] initWithLevel:kSentryLevelInfo];
    event3.timestamp = date;
    event3.sdk = @{
        @"version" : @"0.15.2",
        @"name" : @"sentry-react-native",
        @"integrations" : @[ @"sentry.cocoa" ]
    };
    NSDictionary *serialized3 = @{
        @"event_id" : [event3.eventId sentryIdString],
        @"level" : @"info",
        @"platform" : @"cocoa",
        @"sdk" : @ {
            @"name" : @"sentry-react-native",
            @"version" : @"0.15.2",
            @"integrations" : @[ @"sentry.cocoa" ]
        },
        @"timestamp" : @(date.timeIntervalSince1970)
    };
    XCTAssertEqualObjects([event3 serialize], serialized3);

    SentryEvent *event4 = [[SentryEvent alloc] initWithLevel:kSentryLevelInfo];
    event4.timestamp = date;
    event4.sdk = @{ @"name" : @"sentry.cocoa", @"version" : SentryMeta.versionString };
    event4.extra =
        @{ @"key" : @ { @1 : @"1", @2 : [NSDate dateWithTimeIntervalSince1970:1582803326.1235] } };
    NSDictionary *serialized4 = @{
        @"event_id" : [event4.eventId sentryIdString],
        @"extra" : @ { @"key" : @ { @"1" : @"1", @"2" : @"2020-02-27T11:35:26.124Z" } },
        @"level" : @"info",
        @"platform" : @"cocoa",
        @"sdk" : @ { @"name" : @"sentry.cocoa", @"version" : SentryMeta.versionString },
        @"timestamp" : @(date.timeIntervalSince1970)
    };
    XCTAssertEqualObjects([event4 serialize], serialized4);
}

- (void)testTransactionEvent
{
    NSDate *date = [NSDate date];

    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelInfo];
    event.timestamp = date;
    event.sdk = @{
        @"version" : @"0.15.2",
        @"name" : @"sentry-react-native",
        @"integrations" : @[ @"sentry.cocoa" ]
    };
    NSDictionary *serialized = @{
        @"event_id" : [event.eventId sentryIdString],
        @"level" : @"info",
        @"platform" : @"cocoa",
        @"sdk" : @ {
            @"name" : @"sentry-react-native",
            @"version" : @"0.15.2",
            @"integrations" : @[ @"sentry.cocoa" ]
        },
        @"timestamp" : @(date.timeIntervalSince1970)
    };
    XCTAssertEqualObjects([event serialize], serialized);

    SentryEvent *event3 = [[SentryEvent alloc] initWithLevel:kSentryLevelInfo];
    event3.timestamp = date;
    event3.transaction = @"UIViewControllerTest";
    event3.sdk = @{
        @"version" : @"0.15.2",
        @"name" : @"sentry-react-native",
        @"integrations" : @[ @"sentry.cocoa" ]
    };
    NSDictionary *serialized3 = @{
        @"event_id" : [event3.eventId sentryIdString],
        @"level" : @"info",
        @"transaction" : @"UIViewControllerTest",
        @"platform" : @"cocoa",
        @"sdk" : @ {
            @"name" : @"sentry-react-native",
            @"version" : @"0.15.2",
            @"integrations" : @[ @"sentry.cocoa" ]
        },
        @"timestamp" : @(date.timeIntervalSince1970)
    };
    XCTAssertEqualObjects([event3 serialize], serialized3);
    SentryEvent *event4 = [[SentryEvent alloc] initWithLevel:kSentryLevelInfo];
    event4.timestamp = date;
    NSDate *testDate = [NSDate dateWithTimeIntervalSince1970:1582803326];
    NSURL *testURL = [NSURL URLWithString:@"https://sentry.io"];
    event4.extra = @{
        @"key" : @ {
            @1 : @"1",
            @2 : @2,
            @3 : @ { @"a" : @0 },
            @4 : @[ @"1", @2, @{ @"a" : @0 }, @[ @"a" ], testDate, testURL ],
            @5 : testDate,
            @6 : testURL
        }
    };
    event4.sdk = @{ @"name" : @"sentry.cocoa", @"version" : SentryMeta.versionString };
    NSDictionary *serialized4 = @{
        @"event_id" : [event4.eventId sentryIdString],
        @"extra" : @ {
            @"key" : @ {
                @"1" : @"1",
                @"2" : @2,
                @"3" : @ { @"a" : @0 },
                @"4" : @[
                    @"1", @2, @{ @"a" : @0 }, @[ @"a" ], @"2020-02-27T11:35:26.000Z",
                    @"https://sentry.io"
                ],
                @"5" : @"2020-02-27T11:35:26.000Z",
                @"6" : @"https://sentry.io"
            }
        },
        @"level" : @"info",
        @"platform" : @"cocoa",
        @"sdk" : @ { @"name" : @"sentry.cocoa", @"version" : SentryMeta.versionString },
        @"timestamp" : @(date.timeIntervalSince1970)
    };
    XCTAssertEqualObjects([event4 serialize], serialized4);
}

- (void)testSetDistToNil
{
    SentryEvent *eventEmptyDist = [[SentryEvent alloc] initWithLevel:kSentryLevelInfo];
    eventEmptyDist.releaseName = @"abc";
    XCTAssertNil([[eventEmptyDist serialize] objectForKey:@"dist"]);
    XCTAssertEqualObjects([[eventEmptyDist serialize] objectForKey:@"release"], @"abc");
}

- (void)testStacktrace
{
    SentryFrame *frame = [[SentryFrame alloc] init];
    frame.symbolAddress = @"0x01";
    SentryStacktrace *stacktrace = [[SentryStacktrace alloc] initWithFrames:@[ frame ]
                                                                  registers:@{ @"a" : @"1" }];
    XCTAssertNotNil(stacktrace.frames);
    XCTAssertNotNil(stacktrace.registers);
    [stacktrace fixDuplicateFrames];
    NSDictionary *serialized = @{
        @"frames" : @[ @{ @"symbol_addr" : @"0x01", @"function" : @"<redacted>" } ],
        @"registers" : @ { @"a" : @"1" }
    };
    XCTAssertEqualObjects([stacktrace serialize], serialized);
}

- (void)testThread
{
    SentryThread *thread = [[SentryThread alloc] initWithThreadId:@(1)];
    XCTAssertNotNil(thread.threadId);
    NSDictionary *serialized = @{ @"id" : @(1) };
    XCTAssertEqualObjects([thread serialize], serialized);

    SentryThread *thread2 = [[SentryThread alloc] initWithThreadId:@(2)];
    XCTAssertNotNil(thread2.threadId);
    thread2.crashed = @(YES);
    thread2.current = @(NO);
    thread2.name = @"name";
    SentryFrame *frame = [[SentryFrame alloc] init];
    frame.symbolAddress = @"0x01";
    thread2.stacktrace = [[SentryStacktrace alloc] initWithFrames:@[ frame ]
                                                        registers:@{ @"a" : @"1" }];
    NSDictionary *serialized2 = @{
        @"id" : @(2),
        @"crashed" : @(YES),
        @"current" : @(NO),
        @"name" : @"name",
        @"stacktrace" : @ {
            @"frames" : @[ @{ @"symbol_addr" : @"0x01", @"function" : @"<redacted>" } ],
            @"registers" : @ { @"a" : @"1" }
        }
    };
    XCTAssertEqualObjects([thread2 serialize], serialized2);
}

- (void)testUser
{
    SentryUser *user = [[SentryUser alloc] init];
    user.userId = @"1";
    XCTAssertNotNil(user.userId);
    NSDictionary *serialized = @{ @"id" : @"1" };
    XCTAssertEqualObjects([user serialize], serialized);

    SentryUser *user2 = [[SentryUser alloc] init];
    user2.userId = @"1";
    XCTAssertNotNil(user2.userId);
    user2.email = @"a@b.com";
    user2.username = @"tony";
    user2.data = @{ @"test" : @"a" };
    NSDictionary *serialized2 = @{
        @"id" : @"1",
        @"email" : @"a@b.com",
        @"username" : @"tony",
        @"data" : @ { @"test" : @"a" }
    };
    XCTAssertEqualObjects([user2 serialize], serialized2);
}

- (void)testUserCopy
{
    SentryUser *user = [[SentryUser alloc] init];
    user.userId = @"1";
    user.email = @"a@b.com";
    user.username = @"tony";
    user.data = @{ @"test" : @"a" };

    SentryUser *user2 = user.copy;
    NSDictionary *serialized = [user serialize].mutableCopy;
    XCTAssertEqualObjects(serialized, [user2 serialize]);

    user2.userId = @"2";
    user2.email = @"b@b.com";
    user2.username = @"1tony";
    user2.data = @{ @"1test" : @"a" };

    XCTAssertEqualObjects([user serialize], serialized);

    NSDictionary *serialized2 = @{
        @"id" : @"2",
        @"email" : @"b@b.com",
        @"username" : @"1tony",
        @"data" : @ { @"1test" : @"a" }
    };
    XCTAssertEqualObjects([user2 serialize], serialized2);
}

- (void)testException
{
    SentryException *exception = [[SentryException alloc] initWithValue:@"value" type:@"type"];
    XCTAssertNotNil(exception.value);
    XCTAssertNotNil(exception.type);
    NSDictionary *serialized = @{
        @"value" : @"value",
        @"type" : @"type",
    };
    XCTAssertEqualObjects([exception serialize], serialized);

    SentryException *exception2 = [[SentryException alloc] initWithValue:@"value" type:@"type"];
    XCTAssertNotNil(exception2.value);
    XCTAssertNotNil(exception2.type);

    SentryThread *thread2 = [[SentryThread alloc] initWithThreadId:@(2)];
    XCTAssertNotNil(thread2.threadId);
    thread2.crashed = @(YES);
    thread2.current = @(NO);
    thread2.name = @"name";
    SentryFrame *frame = [[SentryFrame alloc] init];
    frame.symbolAddress = @"0x01";
    thread2.stacktrace = [[SentryStacktrace alloc] initWithFrames:@[ frame ]
                                                        registers:@{ @"a" : @"1" }];

    exception2.threadId = thread2.threadId;
    exception2.stacktrace = thread2.stacktrace;

    exception2.mechanism = [[SentryMechanism alloc] initWithType:@"test"];
    exception2.module = @"module";
    NSDictionary *serialized2 = @{
        @"value" : @"value",
        @"type" : @"type",
        @"thread_id" : @(2),
        @"stacktrace" : @ {
            @"frames" : @[ @{ @"symbol_addr" : @"0x01", @"function" : @"<redacted>" } ],
            @"registers" : @ { @"a" : @"1" }
        },
        @"module" : @"module",
        @"mechanism" : @ { @"type" : @"test" }
    };

    XCTAssertEqualObjects([exception2 serialize], serialized2);
}

- (void)testBreadcrumb
{
    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                                             category:@"http"];
    XCTAssertTrue(crumb.level >= 0);
    XCTAssertNotNil(crumb.category);
    NSDate *date = [NSDate date];
    crumb.timestamp = date;
    NSDictionary *serialized = @{
        @"level" : @"info",
        @"timestamp" : [date sentry_toIso8601String],
        @"category" : @"http",
    };
    XCTAssertEqualObjects([crumb serialize], serialized);

    SentryBreadcrumb *crumb2 = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                                              category:@"http"];
    XCTAssertTrue(crumb2.level >= 0);
    XCTAssertNotNil(crumb2.category);
    crumb2.data = @{ @"bla" : @"1" };
    crumb2.type = @"type";
    crumb2.timestamp = date;
    crumb2.message = @"message";
    NSDictionary *serialized2 = @{
        @"level" : @"info",
        @"type" : @"type",
        @"message" : @"message",
        @"timestamp" : [date sentry_toIso8601String],
        @"category" : @"http",
        @"data" : @ { @"bla" : @"1" },
    };
    XCTAssertEqualObjects([crumb2 serialize], serialized2);
}

@end
