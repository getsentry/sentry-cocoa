#import "SentryDevice.h"
#import <XCTest/XCTest.h>

#define SENTRY_ASSERT_EQUAL(actualString, expectedString) XCTAssert([expectedString isEqualToString:actualString], @"Expected %@ but got %@", expectedString, actualString)
#define SENTRY_ASSERT_CONTAINS(parentString, childString) XCTAssert([parentString containsString:childString], @"Expected %@ to contain %@", parentString, childString)

/**
 * @seealso TargetConditionals.h has explanations and diagrams that show the relationships between different @c TARGET_OS_... macros.
 */
@interface SentryDeviceTests : XCTestCase

@end

@implementation SentryDeviceTests

- (void)testCPUArchitecture
{
    const auto arch = getCPUArchitecture();
#if TARGET_OS_OSX
#if TARGET_CPU_X86_64
    SENTRY_ASSERT_CONTAINS(arch, @"x86");
#else
    SENTRY_ASSERT_CONTAINS(arch, @"arm64");
#endif
#elif TARGET_OS_MACCATALYST
#if TARGET_CPU_X86_64
    SENTRY_ASSERT_CONTAINS(arch, @"x86");
#else
    SENTRY_ASSERT_CONTAINS(arch, @"arm64");
#endif
#elif TARGET_OS_IOS
    // We must test this branch in iOS-SwiftUITests since it must run on device, which SentryTests
    // cannot.
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        SENTRY_ASSERT_CONTAINS(arch, @"arm");
    } else if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        SENTRY_ASSERT_CONTAINS(arch, @"arm");
    } else {
        XCTFail(@"Unsupported iOS UI idiom.");
    }
#elif TARGET_OS_TV
    // We must test this branch in tvOS-SwiftUITests since it must run on device, which SentryTests
    // cannot.
    XCTAssert([arch containsString:@"arm"], @"Expected %@ to contain %@", arch, @"arm");
#elif TARGET_OS_WATCH
    // TODO: create a watch UI test target to test this branch as it cannot run on the watch simulator
    XCTAssert([arch containsString:@"arm"], @"Expected %@ to contain %@", arch, @"arm");
#else
    XCTFail(@"Unexpected device OS");
#endif
}

- (void)testOSVersion {
    XCTAssertNotEqual(getOSVersion().length, 0U);
}

- (void)testOSName {
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
    // TODO: create a watch UI test target to test this branch as it cannot run on the watch simulator
    SENTRY_ASSERT_EQUAL(osName, @"watchOS");
#else
    XCTFail(@"Unexpected device OS");
#endif
}

- (void)testDeviceModel {
    const auto modelName = getDeviceModel();
    XCTAssertNotEqual(modelName.length, 0U);
#if TARGET_OS_SIMULATOR
    SENTRY_ASSERT_CONTAINS(modelName, @"Mac");
#elif TARGET_OS_OSX
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
    // TODO: create a watch UI test target to test this branch as it cannot run on the watch simulator
    SENTRY_ASSERT_CONTAINS(modelName, @"Watch");
#else
    XCTFail(@"Unexpected device OS");
#endif
}

- (void)testOSBuildNumber {
    XCTAssertNotEqual(getOSBuildNumber().length, 0U);
}

- (void)testIsSimulator {
#if TARGET_OS_SIMULATOR
    XCTAssertTrue(isSimulatorBuild());
#else
    XCTAssertFalse(isSimulatorBuild());
#endif
}

- (void)testSimulatedDeviceModel {
#if !TARGET_OS_SIMULATOR
    XCTSkip(@"Should only run on simulators.");
#else
    const auto modelName = getSimulatorDeviceModel();
    XCTAssertNotEqual(modelName.length, 0U);
#if TARGET_OS_IOS
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
    // TODO: create a watch UI test target to test this branch as it cannot run on the watch simulator
    SENTRY_ASSERT_CONTAINS(modelName, @"Watch");
#else
    XCTFail(@"Unexpected device OS");
#endif
#endif
}

@end
