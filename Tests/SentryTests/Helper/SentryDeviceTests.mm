#import "SentryDevice.h"
#import <XCTest/XCTest.h>

#define SENTRY_ASSERT_EQUAL(actualString, expectedString)                                          \
    XCTAssert([expectedString isEqualToString:actualString], @"Expected %@ but got %@",            \
        expectedString, actualString)
#define SENTRY_ASSERT_CONTAINS(parentString, childString)                                          \
    XCTAssert([parentString containsString:childString], @"Expected %@ to contain %@",             \
        parentString, childString)

/**
 * @seealso TargetConditionals.h has explanations and diagrams that show the relationships between
 * different @c TARGET_OS_... macros.
 */
@interface SentryDeviceTests : XCTestCase

@end

@implementation SentryDeviceTests

- (void)testCPUArchitecture
{
    const auto arch = getCPUArchitecture();
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
    XCTAssertNotEqual(getOSVersion().length, 0U);
}

- (void)testOSName
{
    const auto osName = getOSName();
#if TARGET_OS_OSX
    SENTRY_ASSERT_EQUAL(osName, @"macOS");
#elif TARGET_OS_MACCATALYST
    SENTRY_ASSERT_EQUAL(osName, @"iPadOS");
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
    // TODO: create a watch UI test target to test this branch as it cannot run on the watch
    // simulator
    SENTRY_ASSERT_EQUAL(osName, @"watchOS");
#else
    XCTFail(@"Unexpected device OS");
#endif
}

- (void)testDeviceModel
{
    const auto modelName = getDeviceModel();
    XCTAssertNotEqual(modelName.length, 0U);
#if TARGET_OS_OSX
    SENTRY_ASSERT_CONTAINS(modelName, @"Mac");
#elif TARGET_OS_MACCATALYST
    SENTRY_ASSERT_CONTAINS(modelName, @"Mac");
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
    XCTFail(@"Unexpected device OS");
#endif
}

- (void)testOSBuildNumber
{
    XCTAssertNotEqual(getOSBuildNumber().length, 0U);
}

- (void)testIsSimulator
{
#if TARGET_OS_SIMULATOR
    XCTAssertTrue(isSimulatorBuild());
#else
    XCTAssertFalse(isSimulatorBuild());
#endif
}

- (void)testSimulatedDeviceModel
{
#if !TARGET_OS_SIMULATOR
    XCTSkip(@"Should only run on simulators.");
#else
    const auto modelName = getSimulatorDeviceModel();
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
