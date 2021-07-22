#import "SentryOptions.h"
#import "SentryUIViewControllerSwizziling+TestInit.h"
#import "SentryUIViewControllerSwizziling.h"
#import <XCTest/XCTest.h>
#import <objc/runtime.h>

#if SENTRY_HAS_UIKIT
@interface TestViewController : UIViewController
@end

@implementation TestViewController
@end

@interface SentryUIViewControllerSwizzlingTests : XCTestCase

@end

@implementation SentryUIViewControllerSwizzlingTests

- (void)setUp
{
    SentryOptions *options = [[SentryOptions alloc] init];
    NSString *imageName =
        [NSString stringWithCString:class_getImageName(SentryUIViewControllerSwizzlingTests.class)
                           encoding:NSUTF8StringEncoding];
    [options addInAppInclude:imageName.lastPathComponent];
    [SentryUIViewControllerSwizziling startWithOptions:options];
}

- (void)tearDown
{
    [SentryUIViewControllerSwizziling startWithOptions:[[SentryOptions alloc] init]];
}

- (void)testShouldSwizzle_TestViewController
{
    BOOL result =
        [SentryUIViewControllerSwizziling shouldSwizzleViewController:TestViewController.class];

    XCTAssertTrue(result);
}

- (void)testShouldNotSwizzle_UIViewController
{
    BOOL result =
        [SentryUIViewControllerSwizziling shouldSwizzleViewController:UIViewController.class];

    XCTAssertFalse(result);
}

@end

#endif
