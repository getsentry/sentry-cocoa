#import "SentryCrashDynamicLinker.h"
#import <XCTest/XCTest.h>
#import <mach-o/dyld.h>
#import <mach-o/dyld_images.h>
#if TARGET_OS_IOS
#    import <UIKit/UIKit.h>
#endif
#import <Foundation/Foundation.h>

// Added for tests
extern void sentrycrashdl_clearDyld(void);
struct dyld_all_image_infos *getAllImageInfo(void);
extern uint32_t imageIndexContainingAddress(const uintptr_t address);
extern bool sentrycrashbic_shouldAddDyld(void);

@interface SentryCrashDynamicLinkerTests : XCTestCase
@end

@implementation SentryCrashDynamicLinkerTests

- (void)setUp
{
    sentrycrashdl_clearDyld();
}

- (void)testDyldHeaderIsNull
{
    XCTAssert(sentryDyldHeader == NULL, @"sentryDyldHeader should be NULL");
}

- (void)testDyldHeaderInitialization
{
    sentrycrashdl_initialize();

    XCTAssert(sentryDyldHeader != NULL, @"sentryDyldHeader should not be NULL");
    XCTAssertEqual(sentryDyldHeader->magic, MH_MAGIC_64, @"Should be a 64-bit Mach-O header");
}

#if !TARGET_OS_OSX && !TARGET_OS_MACCATALYST
// macOS does have dyld in memory
- (void)testImageIndexContainingAddress
{
    sentrycrashdl_initialize();

    // Test an address within dyld's __TEXT segment
    void *dyldAddress = (void *)&_dyld_image_count;
    uint32_t index = imageIndexContainingAddress((uintptr_t)dyldAddress);
    XCTAssertEqual(index, DYLD_INDEX, @"Address should be found in dyld");
}

- (void)testImageIndexContainingAddressWhenDyldIsNotSet
{
    void *dyldAddress = (void *)&_dyld_image_count;
    uint32_t index = imageIndexContainingAddress((uintptr_t)dyldAddress);
    XCTAssertEqual(index, UINT_MAX, @"Address should be found in dyld");
}
#endif

- (void)testDyldAddressLookup
{
    sentrycrashdl_initialize();

    void *dyldAddress = (void *)&_dyld_image_count;

    Dl_info info;
    bool result = sentrycrashdl_dladdr((uintptr_t)dyldAddress, &info);
    XCTAssertTrue(result, @"dladdr should succeed for dyld address");
    XCTAssert(info.dli_fbase != NULL, @"Base address should not be NULL");
    XCTAssert(info.dli_fname != NULL, @"Image name should not be NULL");

    XCTAssertTrue(strstr(info.dli_fname, "dyld") != NULL, @"Image name should contain 'dyld'");

    XCTAssert(info.dli_sname != NULL, @"Symbol name should not be NULL");
    XCTAssertTrue(strstr(info.dli_sname, "_dyld_image_count") != NULL,
        @"Symbol name should contain '_dyld_image_count'");

    XCTAssert(info.dli_saddr != NULL, @"Symbol address should not be NULL");
    XCTAssertEqual(info.dli_saddr, dyldAddress, @"Symbol address should match the input address");
}

#if TARGET_OS_IOS
- (void)testUIKitAddressLookup
{
    // Get a known function from UIKit
    void *uiKitAddress = (void *)&UIApplicationMain;

    Dl_info info;
    bool result = sentrycrashdl_dladdr((uintptr_t)uiKitAddress, &info);
    XCTAssertTrue(result, @"dladdr should succeed for UIKit address");
    XCTAssert(info.dli_fbase != NULL, @"Base address should not be NULL");
    XCTAssert(info.dli_fname != NULL, @"Image name should not be NULL");

    XCTAssertTrue(strstr(info.dli_fname, "UIKit") != NULL, @"Image name should contain 'UIKit'");

    XCTAssert(info.dli_sname != NULL, @"Symbol name should not be NULL");
    XCTAssertTrue(strstr(info.dli_sname, "UIApplicationMain") != NULL,
        @"Symbol name should contain 'UIApplicationMain'");

    XCTAssert(info.dli_saddr != NULL, @"Symbol address should not be NULL");
    XCTAssertEqual(info.dli_saddr, uiKitAddress, @"Symbol address should match the input address");
}
#endif

- (void)testKnownAddressLookup
{
    // Any function in Sentry will do
    void *testAddress = (void *)&sentrycrashdl_clearDyld;

    Dl_info info;
    bool result = sentrycrashdl_dladdr((uintptr_t)testAddress, &info);
    XCTAssertTrue(result, @"dladdr should succeed for test bundle address");
    XCTAssert(info.dli_fbase != NULL, @"Base address should not be NULL");
    XCTAssert(info.dli_fname != NULL, @"Image name should not be NULL");

    XCTAssertTrue(
        strstr(info.dli_fname, "Sentry") != NULL, @"Image name should contain 'SentryTests'");

    XCTAssert(info.dli_sname != NULL, @"Symbol name should not be NULL");
    XCTAssertTrue(strstr(info.dli_sname, "sentrycrashdl_clearDyld") != NULL,
        @"Symbol name should contain 'sentrycrashdl_clearDyld'");

    XCTAssert(info.dli_saddr != NULL, @"Symbol address should not be NULL");
    XCTAssertEqual(info.dli_saddr, testAddress, @"Symbol address should match the input address");
}

@end
