#import "SentryDevice.h"
#import <XCTest/XCTest.h>

@interface SentryDeviceTests : XCTestCase

@end

@implementation SentryDeviceTests

- (void)testCPUArchitecture
{
#if TARGET_OS_IOS || TARGET_OS_TV
#    if TARGET_OS_SIMULATOR
    [self assertMacCPU:getCPUArchitecture()];
#    else
    // We must test this branch in iOS-SwiftUITests since it must run on device, which SentryTests cannot.
    NSString *arch = getCPUArchitecture();
    XCTAssert([arch containsString:@"arm"], @"Expected an arm architecture but got '%@'", arch);
#    endif
#else
    [self assertMacCPU:getCPUArchitecture()];
#endif
}

- (void)assertMacCPU:(NSString *)arch
{
#if TARGET_CPU_X86_64
    XCTAssert([arch isEqualToString:@"x86_64"], @"Expected 'x86_64' but got '%@'", arch);
#elif TARGET_CPU_ARM64
    XCTAssert([arch containsString:@"arm64"], @"Expected an arm64 arch but got '%@'", arch);
#else
    XCTFail(@"Unexpected target CPU");
#endif
}

@end
