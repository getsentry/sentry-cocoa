@import SentryObjC;
@import XCTest;

#import <TargetConditionals.h>

#if TARGET_OS_IOS
@import UIKit;

@interface SentryObjCUserFeedbackFormControllerTests : XCTestCase
@end

@implementation SentryObjCUserFeedbackFormControllerTests

- (void)testViewController_shouldReturnUIViewController
{
    // -- Act --
    UIViewController *viewController = [SentryObjCFeedbackForm viewController];

    // -- Assert --
    XCTAssertNotNil(viewController);
    XCTAssertTrue([viewController isKindOfClass:UIViewController.class]);
}

- (void)testViewControllerWithScreenshot_shouldReturnUIViewController
{
    // -- Arrange --
    UIImage *screenshot = [[UIImage alloc] init];

    // -- Act --
    UIViewController *viewController =
        [SentryObjCUserFeedbackFormController viewControllerWithScreenshot:screenshot];

    // -- Assert --
    XCTAssertNotNil(viewController);
    XCTAssertTrue([viewController isKindOfClass:UIViewController.class]);
}

- (void)testViewControllerWithConfigure_shouldCallConfigurationCallback
{
    // -- Arrange --
    __block BOOL configureCalled = NO;

    // -- Act --
    UIViewController *viewController = [SentryObjCUserFeedbackFormController
        viewControllerWithConfigure:^(SentryObjCUserFeedbackConfiguration *configuration) {
            configureCalled = YES;
            configuration.animations = NO;
        }];

    // -- Assert --
    XCTAssertTrue(configureCalled);
    XCTAssertNotNil(viewController);
    XCTAssertTrue([viewController isKindOfClass:UIViewController.class]);
}

- (void)testViewControllerWithScreenshotAndConfigure_shouldCallConfigurationCallback
{
    // -- Arrange --
    UIImage *screenshot = [[UIImage alloc] init];
    __block BOOL configureCalled = NO;

    // -- Act --
    UIViewController *viewController = [SentryObjCUserFeedbackFormController
        viewControllerWithScreenshot:screenshot
                           configure:^(SentryObjCUserFeedbackConfiguration *configuration) {
                               configureCalled = YES;
                               configuration.animations = NO;
                           }];

    // -- Assert --
    XCTAssertTrue(configureCalled);
    XCTAssertNotNil(viewController);
    XCTAssertTrue([viewController isKindOfClass:UIViewController.class]);
}

@end

#endif
