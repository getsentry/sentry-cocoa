#import "SentrySdkInfo.h"
#import <XCTest/XCTest.h>

@interface SentrySdkInfoNilTests : XCTestCase

@end

/**
 * Actual tests are written in SentrySdkInfoTests.swift. This class only exists to test
 * passing nil values, which is not possible with Swift cause the compiler avoids it.
 */
@implementation SentrySdkInfoNilTests

- (void)testSdkNameIsNil
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    SentrySdkInfo *actual = [[SentrySdkInfo alloc] initWithName:nil andVersion:@""];
#pragma clang diagnostic pop

    [self assertSdkInfoIsEmtpy:actual];
}

- (void)testVersinoStringIsNil
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    SentrySdkInfo *actual = [[SentrySdkInfo alloc] initWithName:@"" andVersion:nil];
#pragma clang diagnostic pop

    [self assertSdkInfoIsEmtpy:actual];
}

- (void)testInitWithNilDict
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    SentrySdkInfo *actual = [[SentrySdkInfo alloc] initWithDict:nil];
#pragma clang diagnostic pop

    [self assertSdkInfoIsEmtpy:actual];
}

- (void)testInitWithDictWrongTypes
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    SentrySdkInfo *actual =
        [[SentrySdkInfo alloc] initWithDict:@{ @"sdk" : @ { @"name" : @20, @"version" : @0 } }];
#pragma clang diagnostic pop

    [self assertSdkInfoIsEmtpy:actual];
}

- (void)assertSdkInfoIsEmtpy:(SentrySdkInfo *)sdkInfo
{
    XCTAssertEqualObjects(@"", sdkInfo.name);
    XCTAssertEqualObjects(@"", sdkInfo.version);
}

@end
