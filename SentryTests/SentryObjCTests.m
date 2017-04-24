//
//  SentrySwiftObjCTests.m
//  SentrySwift
//
//  Created by Josh Holtz on 3/21/16.
//
//

#import "SentryObjCTests.h"

@import Sentry;

@interface SentrySwiftObjCTests()

@property (nonatomic, strong) SentryClient *client;

@end

@implementation SentrySwiftObjCTests

- (void)setUp {
    _client = [[SentryClient alloc] initWithDsnString:@"https://username:password@app.getsentry.com/12345"];
}

- (void)tearDown {
    _client = nil;
}

- (void)testSharedClient {
    [SentryClient setShared:_client];
    XCTAssertNotNil([SentryClient shared]);
}

- (void)testThatThingsCompileBecauseSwiftToOjbCBridge {
    [SentryClient setLogLevel:SentryLogDebug];
    
    [[SentryClient shared] startCrashHandler];
    [SentryClient shared].user = [[SentryUser alloc] initWithId:@"3" email:@"example@example.com" username:@"Example" extra:@{@"is_admin": @NO}];
    [SentryClient shared].tags = @{@"environment": @"production"};
    [SentryClient shared].extra = @{
                                    @"a_thing": @3,
                                    @"some_things": @[@"green", @"red"],
                                    @"foobar": @{@"foo": @"bar"}
                                    };
    [[SentryClient shared] addExtra:@"__sentry_stack" value:@"__sentry_stack"];
    SentryClient *nilClient = nil;
    [nilClient captureMessage:@"Some plain message from ObjC" level:SentrySeverityInfo];
    
    SentryBreadcrumb *bc = [[SentryBreadcrumb alloc] initWithCategory:@"test" timestamp:[NSDate new] message:@"test message" type:@"test" level:SentrySeverityDebug data:nil];
    [[SentryClient shared].breadcrumbs add:bc];
}

- (void)testEvent {
    NSString *message = @"Thanks for looking at these tests";
    
    NSString *logger = @"paul.bunyan";
    NSString *culprit = @"hewey, dewey, and luey";
    NSString *serverName = @"Janis";
    NSString *release = @"by The Tea Party";
    
    NSDictionary *tags = @{ @"doot": @"doot" };
    NSDictionary *modules = @{ @"2spooky": @"4you" };
    NSDictionary *extra = @{ @"power rangers": @5, @"tmnt": @4 };
    NSArray *fingerprint = @[@"this", @"happened", @"right", @"here"];
    
    SentryException *exc = [[SentryException alloc] initWithValue: @"test-value" type: @"Test" mechanism: nil module: nil];
    
    SentryEvent *event = [[SentryEvent alloc] init:message
                                           eventID:nil
                                         timestamp:[NSDate date]
                                             level:SentrySeverityError
                                            logger:logger
                                           culprit:culprit
                                        serverName:serverName
                                           release:release
                                       buildNumber:@"2123"
                                              tags:tags
                                           modules:modules
                                             extra:extra
                                       fingerprint:fingerprint
                                              user:nil
                                        exceptions: @[exc]
                                        stacktrace:nil];
    
    XCTAssertEqual(event.eventID.length, 32);
    XCTAssertEqualObjects(event.message, message);
    XCTAssertEqual(event.level, SentrySeverityError);
    XCTAssertEqualObjects(event.platform, @"cocoa");
    XCTAssertEqualObjects(event.logger, logger);
    XCTAssertEqualObjects(event.culprit, culprit);
    XCTAssertEqualObjects(event.serverName, serverName);
    XCTAssertEqualObjects(event.releaseVersion, release);
    XCTAssertEqualObjects(event.buildNumber, @"2123");
    XCTAssertEqualObjects(event.tags, tags);
    XCTAssertEqualObjects(event.modules, modules);
    XCTAssertEqualObjects(event.extra, extra);
    XCTAssertEqualObjects(event.fingerprint, fingerprint);
}

@end
