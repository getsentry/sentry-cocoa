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

@end
