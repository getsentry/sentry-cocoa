#import "SentrySdkInterface.h"
#import <XCTest/XCTest.h>

@interface SentrySdkInterfaceNilTests : XCTestCase

@end

/**
 * Actual tests are written in SentrySdkInterfaceTests.swift. This class only exists to test
 * passing nil values, which is not possible with Swift cause the compiler avoids it.
 */
@implementation SentrySdkInterfaceNilTests

- (void)testSdkNameIsNil
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    SentrySdkInterface *actual = [[SentrySdkInterface alloc] initWithName:nil andVersion:@""];
#pragma clang diagnostic pop

    [self assertSdkInterfaceIsEmtpy:actual];
}

- (void)testVersinoStringIsNil
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    SentrySdkInterface *actual = [[SentrySdkInterface alloc] initWithName:@"" andVersion:nil];
#pragma clang diagnostic pop

    [self assertSdkInterfaceIsEmtpy:actual];
}

- (void)testInitWithNilDict
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    SentrySdkInterface *actual = [[SentrySdkInterface alloc] initWithDict:nil];
#pragma clang diagnostic pop

    [self assertSdkInterfaceIsEmtpy:actual];
}

- (void)assertSdkInterfaceIsEmtpy:(SentrySdkInterface *)sdkInterface
{
    XCTAssertEqualObjects(@"", sdkInterface.name);
    XCTAssertEqualObjects(@"", sdkInterface.version);
}

@end
