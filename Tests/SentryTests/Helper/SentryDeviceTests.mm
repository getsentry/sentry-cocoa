#import "SentryDevice.h"
#import <XCTest/XCTest.h>

#define SENTRY_ASSERT_EQUAL(actualString, expectedString)                                          \
    XCTAssert([expectedString isEqualToString:actualString], @"Expected %@ but got %@",            \
        expectedString, actualString)
#define SENTRY_ASSERT_CONTAINS(parentString, childString)                                          \
    XCTAssert([parentString containsString:childString], @"Expected %@ to contain %@",             \
        parentString, childString)
#define SENTRY_ASSERT_PREFIX(reportedVersion, ...)                                                 \
    const auto acceptableVersions = @[ __VA_ARGS__ ];                                              \
    auto foundPrefix = NO;                                                                         \
    for (NSString * prefix in acceptableVersions) {                                                \
        if ([osVersion hasPrefix:prefix]) {                                                        \
            foundPrefix = YES;                                                                     \
            break;                                                                                 \
        }                                                                                          \
    }                                                                                              \
    XCTAssertTrue(foundPrefix,                                                                     \
        @"Expected major version to be one of %@. Actual version reported was %@",                 \
        acceptableVersions, reportedVersion);

/**
 * @seealso TargetConditionals.h has explanations and diagrams that show the relationships between
 * different @c TARGET_OS_... macros.
 */
@interface SentryDeviceTests : XCTestCase

@end

@implementation SentryDeviceTests

- (void)testCPUArchitecture
{
    const auto arch = sentry_getCPUArchitecture();
#if TARGET_OS_OSX
#    if TARGET_CPU_X86_64
    // I observed this branch still being taken when running unit tests for macOS in Xcode 13.4.1 on
    // an Apple Silicon MBP (armcknight 23 Sep 2022)
    SENTRY_ASSERT_CONTAINS(arch, @"x86"); // Macs with Intel CPUs
#    else
    SENTRY_ASSERT_CONTAINS(arch, @"arm64"); // Macs with Apple Silicon
#    endif
#elif TARGET_OS_MACCATALYST
#    if TARGET_CPU_X86_64
    // I observed this branch still being taken when running unit tests for mac catalyst in
    // Xcode 13.4.1 on an Apple Silicon MBP (armcknight 23 Sep 2022)
    SENTRY_ASSERT_CONTAINS(arch, @"x86"); // Macs with Intel CPUs
#    else
    SENTRY_ASSERT_CONTAINS(arch, @"arm64"); // Macs with Apple Silicon
#    endif
#elif TARGET_OS_IOS
#    if TARGET_OS_SIMULATOR
#        if TARGET_CPU_ARM64
    SENTRY_ASSERT_CONTAINS(arch, @"arm"); // iPhone simulator on M1 macs
#        elif TARGET_CPU_X86_64
    SENTRY_ASSERT_CONTAINS(arch, @"x86"); // iPhone simulator on Intel macs
#        else
    XCTFail(@"Unexpected CPU type on test host.");
#        endif // TARGET_CPU_ARM64
#    else
    SENTRY_ASSERT_CONTAINS(arch, @"arm"); // Real iPads and iPhones
#    endif
#elif TARGET_OS_TV
    // We must test this branch in tvOS-SwiftUITests since it must run on device, which SentryTests
    // cannot.
#    if TARGET_OS_SIMULATOR
#        if TARGET_CPU_ARM64
    SENTRY_ASSERT_CONTAINS(arch, @"arm"); // TV simulator on M1 macs
#        elif TARGET_CPU_X86_64
    SENTRY_ASSERT_CONTAINS(arch, @"x86"); // TV simulator on Intel macs
#        else
    XCTFail(@"Unexpected CPU type on test host.");
#        endif // TARGET_CPU_ARM64
#    else
    SENTRY_ASSERT_CONTAINS(arch, @"arm"); // Real TVs
#    endif
#elif TARGET_OS_WATCH
    // TODO: create a watch UI test target to test this branch as it cannot run on the watch
    // simulator
    SENTRY_ASSERT_CONTAINS(arch, @"arm"); // Real Watches
#else
    XCTFail(@"Unexpected device OS");
#endif
}

- (void)testOSVersion
{
    const auto osVersion = sentry_getOSVersion();
    XCTAssertNotEqual(osVersion.length, 0U);
#if TARGET_OS_OSX
    SENTRY_ASSERT_PREFIX(osVersion, @"10.", @"11.", @"12.", @"13.");
#elif TARGET_OS_IOS || TARGET_OS_MACCATALYST || TARGET_OS_TV
    SENTRY_ASSERT_PREFIX(
        osVersion, @"9.", @"10.", @"11.", @"12.", @"13.", @"14.", @"15.", @"16.", @"17.");
#elif TARGET_OS_WATCH
    // TODO: create a watch UI test target to test this branch
    SENTRY_ASSERT_PREFIX(osVersion, @"2.", @"3.", @"4.", @"5.", @"6.", @"7.", @"8.", @"9.");
#else
    XCTFail(@"Unexpected OS.");
#endif
}

- (void)testOSName
{
    const auto osName = sentry_getOSName();
#if TARGET_OS_OSX
    SENTRY_ASSERT_EQUAL(osName, @"macOS");
#elif TARGET_OS_MACCATALYST
    SENTRY_ASSERT_EQUAL(osName, @"Catalyst");
#elif TARGET_OS_IOS
    // We must test this branch in iOS-SwiftUITests since it must run on device, which SentryTests
    // cannot.
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        SENTRY_ASSERT_EQUAL(osName, @"iPadOS");
    } else if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        SENTRY_ASSERT_EQUAL(osName, @"iOS");
    } else {
        XCTFail(@"Unsupported iOS UI idiom.");
    }
#elif TARGET_OS_TV
    // We must test this branch in tvOS-SwiftUITests since it must run on device, which SentryTests
    // cannot.
    SENTRY_ASSERT_EQUAL(osName, @"tvOS");
#elif TARGET_OS_WATCH
    // TODO: create a watch UI test target to test this branch
    SENTRY_ASSERT_EQUAL(osName, @"watchOS");
#else
    XCTFail(@"Unexpected device OS");
#endif
}

- (void)testDeviceModel
{
    const auto modelName = sentry_getDeviceModel();
    XCTAssertNotEqual(modelName.length, 0U);
#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
    NSString *VMware = @"VMware";
    NSString *mac = @"Mac";
    BOOL containsExpectedDevice =
        [modelName containsString:VMware] || [modelName containsString:mac];
    XCTAssertTrue(
        containsExpectedDevice, @"Expected %@ to contain either %@ or %@", modelName, VMware, mac);
#elif TARGET_OS_IOS
    // We must test this branch in iOS-SwiftUITests since it must run on device, which SentryTests
    // cannot.
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        SENTRY_ASSERT_CONTAINS(modelName, @"iPad");
    } else if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        SENTRY_ASSERT_CONTAINS(modelName, @"iPhone");
    } else {
        XCTFail(@"Unsupported iOS UI idiom.");
    }
#elif TARGET_OS_TV
    // We must test this branch in tvOS-SwiftUITests since it must run on device, which SentryTests
    // cannot.
    SENTRY_ASSERT_CONTAINS(modelName, @"TV");
#elif TARGET_OS_WATCH
    // TODO: create a watch UI test target to test this branch as it cannot run on the watch
    // simulator
    SENTRY_ASSERT_CONTAINS(modelName, @"Watch");
#else
    XCTFail(@"Unexpected target OS");
#endif
}

- (void)testOSBuildNumber
{
    XCTAssertNotEqual(sentry_getOSBuildNumber().length, 0U);
}

- (void)testIsSimulator
{
#if TARGET_OS_SIMULATOR
    XCTAssertTrue(sentry_isSimulatorBuild());
#else
    XCTAssertFalse(sentry_isSimulatorBuild());
#endif
}

- (void)testSimulatedDeviceModel
{
#if !TARGET_OS_SIMULATOR
    XCTSkip(@"Should only run on simulators.");
#else
    const auto modelName = sentry_getSimulatorDeviceModel();
    XCTAssertNotEqual(modelName.length, 0U);
#    if TARGET_OS_IOS
    // We must test this branch in iOS-SwiftUITests since it must run on device, which SentryTests
    // cannot.
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        SENTRY_ASSERT_CONTAINS(modelName, @"iPad");
    } else if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        SENTRY_ASSERT_CONTAINS(modelName, @"iPhone");
    } else {
        XCTFail(@"Unsupported iOS UI idiom.");
    }
#    elif TARGET_OS_TV
    // We must test this branch in tvOS-SwiftUITests since it must run on device, which SentryTests
    // cannot.
    SENTRY_ASSERT_CONTAINS(modelName, @"TV");
#    elif TARGET_OS_WATCH
    // TODO: create a watch UI test target to test this branch as it cannot run on the watch
    // simulator
    SENTRY_ASSERT_CONTAINS(modelName, @"Watch");
#    else
    XCTFail(@"Unexpected device OS");
#    endif
#endif
}

@end
