#import "SentryCrashDynamicLinker+Test.h"
#import "SentryCrashDynamicLinker.h"
#import <XCTest/XCTest.h>
#import <mach-o/dyld.h>
#import <mach-o/dyld_images.h>
#if TARGET_OS_IOS
#    import <UIKit/UIKit.h>
#endif
#import <Foundation/Foundation.h>

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

- (void)testImageIndexContainingAddress
{
    sentrycrashdl_initialize();

    uintptr_t addressToFind = [self findDyldAddress];
    uint32_t index = imageIndexContainingAddress((uintptr_t)addressToFind);
    XCTAssertEqual(index, SENTRY_DYLD_INDEX, @"Address should be found in dyld");
}

- (void)testImageIndexContainingAddressWhenDyldIsNotSet
{
    uintptr_t addressToFind = [self findDyldAddress];
    uint32_t index = imageIndexContainingAddress((uintptr_t)addressToFind);
    XCTAssertEqual(index, UINT_MAX, @"Address should be found in dyld");
}

// vmaddrs changes by platform, so we cannot use a static value
- (uintptr_t)findDyldAddress
{
    struct dyld_all_image_infos *infos = getAllImageInfo();
    const struct mach_header *header = NULL;
    if (infos && infos->dyldImageLoadAddress) {
        header = (const struct mach_header *)infos->dyldImageLoadAddress;
    }

    return (uintptr_t)getSegmentAddress(header, SEG_TEXT).start;
}

@end
