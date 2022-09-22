#import <XCTest/XCTest.h>
#import "SentryDefines.h"
#import "SentryDevice.h"

@interface SentryDeviceTests : XCTestCase

@end

@implementation SentryDeviceTests

- (void)testCPUArchitecture {
#if SENTRY_HAS_UIKIT
#if TARGET_OS_SIMULATOR
    [self assertMacCPU:getCPUArchitecture()];
#else
    XCTAssert([getCPUArchitecture() containsString:@"arm"]);
#endif
#else
    [self assertMacCPU:getCPUArchitecture()];
#endif
}

- (void)assertMacCPU:(NSString *)arch {
#if TARGET_CPU_X86_64
    XCTAssertEqual(arch, @"x86_64");
#elif TARGET_CPU_ARM64
    XCTAssert([arch containsString:@"arm64"]);
#else
    XCTFail(@"Unexpected target CPU");
#endif
}

@end
