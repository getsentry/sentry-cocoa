#import "SentryBreadcrumb.h"
#import "SentryOptions+Private.h"
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

    [scope removeExtraForKey:@"A"];
    [scope setExtraValue:nil forKey:@"C"];

    NSDictionary<NSString *, NSString *> *actual = scope.serialize[@"extra"];
    XCTAssertTrue([@{ @"B" : @2 } isEqualToDictionary:actual]);
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

    [scope removeTagForKey:@"A"];

    NSDictionary<NSString *, NSString *> *actual = scope.serialize[@"tags"];
    XCTAssertTrue([@{ @"B" : @"2" } isEqualToDictionary:actual]);
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

    [scope removeContextForKey:@"B"];

    NSDictionary *actual = scope.serialize[@"context"];
    NSDictionary *expected = @{ @"A" : @ { @"AA" : @1 } };
    XCTAssertTrue([expected isEqualToDictionary:actual]);
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
    NSString *expectedEnvironment = kSentryDefaultEnvironment;
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

@end
