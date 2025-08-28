#import "SentrySdkInfo.h"
#import <Sentry/Sentry-Swift.h>
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
    SentrySdkInfo *actual =
        [[SentrySdkInfo alloc] initWithName:nil
                                    version:@""
                               integrations:@[]
                                   features:@[]
                                   packages:@[]
                                   settings:[[SentrySDKSettings alloc] initWithDict:@{}]];
#pragma clang diagnostic pop

    [self assertSdkInfoIsEmtpy:actual];
}

- (void)testVersinStringIsNil
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    SentrySdkInfo *actual =
        [[SentrySdkInfo alloc] initWithName:@""
                                    version:nil
                               integrations:@[]
                                   features:@[]
                                   packages:@[]
                                   settings:[[SentrySDKSettings alloc] initWithDict:@{}]];
#pragma clang diagnostic pop

    [self assertSdkInfoIsEmtpy:actual];
}

- (void)testIntegrationsAreNil
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    SentrySdkInfo *actual =
        [[SentrySdkInfo alloc] initWithName:@""
                                    version:@""
                               integrations:nil
                                   features:@[]
                                   packages:@[]
                                   settings:[[SentrySDKSettings alloc] initWithDict:@{}]];
#pragma clang diagnostic pop

    [self assertSdkInfoIsEmtpy:actual];
}

- (void)testFeaturesAreNil
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    SentrySdkInfo *actual =
        [[SentrySdkInfo alloc] initWithName:@""
                                    version:@""
                               integrations:@[]
                                   features:nil
                                   packages:@[]
                                   settings:[[SentrySDKSettings alloc] initWithDict:@{}]];
#pragma clang diagnostic pop

    [self assertSdkInfoIsEmtpy:actual];
}

- (void)testPackagesAreNil
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    SentrySdkInfo *actual =
        [[SentrySdkInfo alloc] initWithName:@""
                                    version:@""
                               integrations:@[]
                                   features:@[]
                                   packages:nil
                                   settings:[[SentrySDKSettings alloc] initWithDict:@{}]];
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
        [[SentrySdkInfo alloc] initWithDict:@{ @"name" : @20, @"version" : @0 }];
#pragma clang diagnostic pop

    [self assertSdkInfoIsEmtpy:actual];
}

- (void)assertSdkInfoIsEmtpy:(SentrySdkInfo *)sdkInfo
{
    XCTAssertEqualObjects(@"", sdkInfo.name);
    XCTAssertEqualObjects(@"", sdkInfo.version);
    XCTAssertEqualObjects(@[], sdkInfo.integrations);
    XCTAssertEqualObjects(@[], sdkInfo.features);
    // Default value for autoInferIP is false
    XCTAssertEqual(sdkInfo.settings.autoInferIP, NO);
}

@end
