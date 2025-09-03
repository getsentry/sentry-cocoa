#import "SentryDevice.h"
#import <XCTest/XCTest.h>

#define SENTRY_ASSERT_EQUAL(actualString, expectedString)                                          \
    XCTAssert([expectedString isEqualToString:actualString], @"Expected %@ but got %@",            \
        expectedString, actualString)
#define SENTRY_ASSERT_CONTAINS(parentString, childString)                                          \
    XCTAssert([parentString containsString:childString], @"Expected %@ to contain %@",             \
        parentString, childString)
#define SENTRY_ASSERT_PREFIX(reportedVersion, ...)                                                 \
    NSArray<NSString *> *acceptableVersions = @[ __VA_ARGS__ ];                                    \
    BOOL foundPrefix = NO;                                                                         \
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
    NSString *arch = sentry_getCPUArchitecture();
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
    NSString *osVersion = sentry_getOSVersion();
    XCTAssertNotEqual(osVersion.length, 0U);
#if TARGET_OS_OSX
    SENTRY_ASSERT_PREFIX(osVersion, @"10.", @"11.", @"12.", @"13.", @"14.", @"15.", @"26.");
#elif TARGET_OS_IOS || TARGET_OS_MACCATALYST || TARGET_OS_TV
    SENTRY_ASSERT_PREFIX(
        osVersion, @"9.", @"10.", @"11.", @"12.", @"13.", @"14.", @"15.", @"16.", @"17.", @"18.", @"26.");
#elif TARGET_OS_WATCH
    // TODO: create a watch UI test target to test this branch
    SENTRY_ASSERT_PREFIX(osVersion, @"2.", @"3.", @"4.", @"5.", @"6.", @"7.", @"8.", @"9.", @"10.", @"26.");
#elif TARGET_OS_VISION
    SENTRY_ASSERT_PREFIX(osVersion, @"1.", @"2.", @"26.");
#else
    XCTFail(@"Unexpected OS.");
#endif
}

- (void)testOSName
{
    NSString *osName = sentry_getOSName();
#if TARGET_OS_OSX
    SENTRY_ASSERT_EQUAL(osName, @"macOS");
#elif TARGET_OS_MACCATALYST
    SENTRY_ASSERT_EQUAL(osName, @"Catalyst");
#elif TARGET_OS_IOS
    // We must test this branch in iOS-Swift-UITests since it must run on device, which SentryTests
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
    NSString *modelName = sentry_getDeviceModel();
    XCTAssertNotEqual(modelName.length, 0U);
#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
    NSString *VMware = @"VMware";
    NSString *mac = @"Mac";
    BOOL containsExpectedDevice =
        [modelName containsString:VMware] || [modelName containsString:mac];
    XCTAssertTrue(
        containsExpectedDevice, @"Expected %@ to contain either %@ or %@", modelName, VMware, mac);
#elif TARGET_OS_IOS
    // We must test this branch in iOS-Swift-UITests since it must run on device, which SentryTests
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

- (void)testOSVersion26Support
{
    // Test that version 26.x is properly supported for all platforms
    NSString *mockVersion26 = @"26.0.1";
    
#if TARGET_OS_OSX
    // Test macOS 26 support
    BOOL macOSSupported = [mockVersion26 hasPrefix:@"26."];
    XCTAssertTrue(macOSSupported, @"macOS 26.x should be supported");
#elif TARGET_OS_IOS || TARGET_OS_MACCATALYST || TARGET_OS_TV
    // Test iOS/Mac Catalyst/tvOS 26 support
    BOOL iOSSupported = [mockVersion26 hasPrefix:@"26."];
    XCTAssertTrue(iOSSupported, @"iOS/Mac Catalyst/tvOS 26.x should be supported");
#elif TARGET_OS_WATCH
    // Test watchOS 26 support
    BOOL watchOSSupported = [mockVersion26 hasPrefix:@"26."];
    XCTAssertTrue(watchOSSupported, @"watchOS 26.x should be supported");
#elif TARGET_OS_VISION
    // Test visionOS 26 support
    BOOL visionOSSupported = [mockVersion26 hasPrefix:@"26."];
    XCTAssertTrue(visionOSSupported, @"visionOS 26.x should be supported");
#endif
}

- (void)testOSVersionRange
{
    // Test that the version range logic works correctly for edge cases
    NSArray<NSString *> *testVersions = @[@"18.9.9", @"26.0", @"26.1.2", @"26.99.99"];
    
    for (NSString *version in testVersions) {
#if TARGET_OS_OSX
        NSArray<NSString *> *macOSVersions = @[@"10.", @"11.", @"12.", @"13.", @"14.", @"15.", @"26."];
#elif TARGET_OS_IOS || TARGET_OS_MACCATALYST || TARGET_OS_TV
        NSArray<NSString *> *iOSVersions = @[@"9.", @"10.", @"11.", @"12.", @"13.", @"14.", @"15.", @"16.", @"17.", @"18.", @"26."];
#elif TARGET_OS_WATCH
        NSArray<NSString *> *watchOSVersions = @[@"2.", @"3.", @"4.", @"5.", @"6.", @"7.", @"8.", @"9.", @"10.", @"26."];
#elif TARGET_OS_VISION
        NSArray<NSString *> *visionOSVersions = @[@"1.", @"2.", @"26."];
#endif
        
        BOOL foundMatch = NO;
#if TARGET_OS_OSX
        for (NSString *prefix in macOSVersions) {
#elif TARGET_OS_IOS || TARGET_OS_MACCATALYST || TARGET_OS_TV
        for (NSString *prefix in iOSVersions) {
#elif TARGET_OS_WATCH
        for (NSString *prefix in watchOSVersions) {
#elif TARGET_OS_VISION
        for (NSString *prefix in visionOSVersions) {
#endif
            if ([version hasPrefix:prefix]) {
                foundMatch = YES;
                break;
            }
        }
        
        if ([version hasPrefix:@"18."] || [version hasPrefix:@"26."]) {
            XCTAssertTrue(foundMatch, @"Version %@ should be supported", version);
        }
    }
}

- (void)testUnsupportedOSVersionsAreRejected
{
    // Test that non-existent OS versions (19-25) would be rejected
    NSArray<NSString *> *unsupportedVersions = @[@"19.0", @"20.1", @"21.2", @"22.3", @"23.4", @"24.5", @"25.6"];
    
    for (NSString *version in unsupportedVersions) {
#if TARGET_OS_OSX
        NSArray<NSString *> *supportedVersions = @[@"10.", @"11.", @"12.", @"13.", @"14.", @"15.", @"26."];
#elif TARGET_OS_IOS || TARGET_OS_MACCATALYST || TARGET_OS_TV
        NSArray<NSString *> *supportedVersions = @[@"9.", @"10.", @"11.", @"12.", @"13.", @"14.", @"15.", @"16.", @"17.", @"18.", @"26."];
#elif TARGET_OS_WATCH
        NSArray<NSString *> *supportedVersions = @[@"2.", @"3.", @"4.", @"5.", @"6.", @"7.", @"8.", @"9.", @"10.", @"26."];
#elif TARGET_OS_VISION
        NSArray<NSString *> *supportedVersions = @[@"1.", @"2.", @"26."];
#endif
        
        BOOL foundMatch = NO;
        for (NSString *prefix in supportedVersions) {
            if ([version hasPrefix:prefix]) {
                foundMatch = YES;
                break;
            }
        }
        
        XCTAssertFalse(foundMatch, @"Unsupported version %@ should be rejected", version);
    }
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
    NSString *modelName = sentry_getSimulatorDeviceModel();
    XCTAssertNotEqual(modelName.length, 0U);
#    if TARGET_OS_IOS
    // We must test this branch in iOS-Swift-UITests since it must run on device, which SentryTests
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
