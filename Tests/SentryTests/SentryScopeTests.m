#import "SentryBreadcrumb.h"
#import "SentryScope+Private.h"
#import "SentryScope.h"
#import "SentryUser.h"
#import <XCTest/XCTest.h>

@interface SentryScopeTests : XCTestCase

@end

@implementation SentryScopeTests

- (SentryBreadcrumb *)getBreadcrumb
{
    return [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelDebug category:@"http"];
}

- (void)testSetExtra
{
    SentryScope *scope = [[SentryScope alloc] init];
    [scope setExtras:@{ @"c" : @"d" }];
    XCTAssertEqualObjects([[scope serialize] objectForKey:@"extra"], @{ @"c" : @"d" });
}

- (void)testRemoveExtra
{
    SentryScope *scope = [[SentryScope alloc] init];
    [scope setExtraValue:@1 forKey:@"A"];
    [scope setExtraValue:@2 forKey:@"B"];
    [scope setExtraValue:@3 forKey:@"C"];

    __block BOOL wasListenerCalled = false;
    [scope addScopeListener:^(
        SentryScope *_Nonnull __attribute__((unused)) scope) { wasListenerCalled = true; }];
    [scope removeExtraForKey:@"A"];
    [scope setExtraValue:nil forKey:@"C"];

    NSDictionary<NSString *, NSString *> *actual = scope.serialize[@"extra"];
    XCTAssertTrue([@{ @"B" : @2 } isEqualToDictionary:actual]);
    XCTAssertTrue(wasListenerCalled);
}

- (void)testBreadcrumbOlderReplacedByNewer
{
    NSUInteger expectedMaxBreadcrumb = 1;
    SentryScope *scope = [[SentryScope alloc] initWithMaxBreadcrumbs:expectedMaxBreadcrumb];
    SentryBreadcrumb *crumb1 = [[SentryBreadcrumb alloc] init];
    [crumb1 setMessage:@"crumb 1"];
    [scope addBreadcrumb:crumb1];
    NSDictionary<NSString *, id> *scope1 = [scope serialize];
    NSArray *scope1Crumbs = [scope1 objectForKey:@"breadcrumbs"];
    XCTAssertEqual(expectedMaxBreadcrumb, [scope1Crumbs count]);

    SentryBreadcrumb *crumb2 = [[SentryBreadcrumb alloc] init];
    [crumb2 setMessage:@"crumb 2"];
    [scope addBreadcrumb:crumb2];
    NSDictionary<NSString *, id> *scope2 = [scope serialize];
    NSArray *scope2Crumbs = [scope2 objectForKey:@"breadcrumbs"];
    XCTAssertEqual(expectedMaxBreadcrumb, [scope2Crumbs count]);
}

- (void)testDefaultMaxCapacity
{
    SentryScope *scope = [[SentryScope alloc] init];
    for (int i = 0; i < 2000; ++i) {
        [scope addBreadcrumb:[[SentryBreadcrumb alloc] init]];
    }

    NSDictionary<NSString *, id> *scopeSerialized = [scope serialize];
    NSArray *scopeCrumbs = [scopeSerialized objectForKey:@"breadcrumbs"];
    XCTAssertEqual(100, [scopeCrumbs count]);
}

- (void)testSetTagValueForKey
{
    NSDictionary<NSString *, NSString *> *excpected = @{ @"A" : @"1", @"B" : @"2", @"C" : @"" };

    SentryScope *scope = [[SentryScope alloc] init];
    [scope setTagValue:@"1" forKey:@"A"];
    [scope setTagValue:@"overwriteme" forKey:@"B"];
    [scope setTagValue:@"2" forKey:@"B"];
    [scope setTagValue:@"" forKey:@"C"];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [scope setTagValue:nil forKey:@"D"];
#pragma clang diagnostic pop

    NSDictionary<NSString *, NSString *> *actual = scope.serialize[@"tags"];
    XCTAssertTrue([excpected isEqualToDictionary:actual]);
}

- (void)testRemoveTag
{
    SentryScope *scope = [[SentryScope alloc] init];
    [scope setTagValue:@"1" forKey:@"A"];
    [scope setTagValue:@"2" forKey:@"B"];

    __block BOOL wasListenerCalled = false;
    [scope addScopeListener:^(
        SentryScope *_Nonnull __attribute__((unused)) scope) { wasListenerCalled = true; }];
    [scope removeTagForKey:@"A"];

    NSDictionary<NSString *, NSString *> *actual = scope.serialize[@"tags"];
    XCTAssertTrue([@{ @"B" : @"2" } isEqualToDictionary:actual]);
    XCTAssertTrue(wasListenerCalled);
}

- (void)testSetUser
{
    SentryScope *scope = [[SentryScope alloc] init];
    SentryUser *user = [[SentryUser alloc] init];

    [user setUserId:@"123"];
    [scope setUser:user];

    NSDictionary<NSString *, id> *scopeSerialized = [scope serialize];
    NSDictionary<NSString *, id> *scopeUser = [scopeSerialized objectForKey:@"user"];
    NSString *scopeUserId = [scopeUser objectForKey:@"id"];

    XCTAssertEqualObjects(scopeUserId, @"123");
}

- (void)testSetContextValueForKey
{
    SentryScope *scope = [[SentryScope alloc] init];
    [scope setContextValue:@{ @"AA" : @1 } forKey:@"A"];
    [scope setContextValue:@{ @"BB" : @"2" } forKey:@"B"];

    NSDictionary *actual = scope.serialize[@"context"];
    NSDictionary *expected = @{ @"A" : @ { @"AA" : @1 }, @"B" : @ { @"BB" : @"2" } };
    XCTAssertTrue([expected isEqualToDictionary:actual]);
}

- (void)testRemoveContextForKey
{
    SentryScope *scope = [[SentryScope alloc] init];
    [scope setContextValue:@{ @"AA" : @1 } forKey:@"A"];
    [scope setContextValue:@{ @"BB" : @"2" } forKey:@"B"];

    __block BOOL wasListenerCalled = false;
    [scope addScopeListener:^(
        SentryScope *_Nonnull __attribute__((unused)) scope) { wasListenerCalled = true; }];
    [scope removeContextForKey:@"B"];

    NSDictionary *actual = scope.serialize[@"context"];
    NSDictionary *expected = @{ @"A" : @ { @"AA" : @1 } };
    XCTAssertTrue([expected isEqualToDictionary:actual]);
    XCTAssertTrue(wasListenerCalled);
}

- (void)testDistSerializes
{
    SentryScope *scope = [[SentryScope alloc] init];
    NSString *expectedDist = @"dist-1.0";
    [scope setDist:expectedDist];
    XCTAssertEqualObjects([[scope serialize] objectForKey:@"dist"], expectedDist);
}

- (void)testEnvironmentSerializes
{
    SentryScope *scope = [[SentryScope alloc] init];
    NSString *expectedEnvironment = @"production";
    [scope setEnvironment:expectedEnvironment];
    XCTAssertEqualObjects([[scope serialize] objectForKey:@"environment"], expectedEnvironment);
}

- (void)testClearBreadcrumb
{
    SentryScope *scope = [[SentryScope alloc] init];
    [scope clearBreadcrumbs];
    [scope addBreadcrumb:[self getBreadcrumb]];
    [scope clearBreadcrumbs];
    XCTAssertTrue([[[scope serialize] objectForKey:@"breadcrumbs"] count] == 0);
}

- (void)testListeners
{
    XCTestExpectation *expectation =
        [self expectationWithDescription:@"Should call scope listener"];
    SentryScope *scope = [[SentryScope alloc] init];
    [scope addScopeListener:^(SentryScope *_Nonnull scope) {
        XCTAssertEqualObjects([[scope serialize] objectForKey:@"extra"], @ { @"a" : @"b" });
        [expectation fulfill];
    }];
    [scope setExtras:@{ @"a" : @"b" }];
    [self waitForExpectations:@[ expectation ] timeout:5.0];
}

- (void)testInitWithScope
{
    SentryScope *scope = [[SentryScope alloc] init];
    [scope setExtras:@{ @"a" : @"b" }];
    [scope setTags:@{ @"b" : @"c" }];
    [scope addBreadcrumb:[self getBreadcrumb]];
    [scope setUser:[[SentryUser alloc] initWithUserId:@"id"]];
    [scope setContextValue:@{ @"e" : @"f" } forKey:@"myContext"];
    [scope setDist:@"456"];
    [scope setEnvironment:@"789"];
    [scope setFingerprint:@[ @"a" ]];

    NSMutableDictionary *snapshot = [scope serialize].mutableCopy;

    SentryScope *cloned = [[SentryScope alloc] initWithScope:scope];
    XCTAssertEqualObjects(snapshot, [cloned serialize]);

    [cloned setExtras:@{ @"aa" : @"b" }];
    [cloned setTags:@{ @"ab" : @"c" }];
    [cloned addBreadcrumb:[[SentryBreadcrumb alloc] initWithLevel:kSentryLevelDebug
                                                         category:@"http2"]];
    [cloned setUser:[[SentryUser alloc] initWithUserId:@"aid"]];
    [cloned setContextValue:@{ @"ae" : @"af" } forKey:@"myContext"];
    [cloned setDist:@"a456"];
    [cloned setEnvironment:@"a789"];

    XCTAssertEqualObjects(snapshot, [scope serialize]);
    XCTAssertNotEqualObjects([scope serialize], [cloned serialize]);
}

@end
