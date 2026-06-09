@import SentryObjC;
@import XCTest;

#import <TargetConditionals.h>

#if TARGET_OS_IOS
@import UIKit;

@interface SentryObjCFeedbackApiTests : XCTestCase
@end

@implementation SentryObjCFeedbackApiTests

- (void)testShow_whenNoPresenter_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.feedback show];
}

- (void)testShowWithScreenshot_whenNilScreenshot_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.feedback showWithScreenshot:nil];
}

- (void)testShowWithConfigure_whenNoPresenter_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.feedback showWithConfigure:^(
        SentryObjCUserFeedbackConfiguration *configuration) { configuration.animations = NO; }];
}

- (void)testShowWithScreenshotAndConfigure_whenNoPresenter_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.feedback
        showWithScreenshot:nil
                 configure:^(SentryObjCUserFeedbackConfiguration *configuration) {
                     configuration.animations = NO;
                 }];
}

- (void)testFormViewController_shouldReturnUIViewController
{
    // -- Act --
    UIViewController *viewController = [SentryObjCSDK.feedback formViewController];

    // -- Assert --
    XCTAssertNotNil(viewController);
    XCTAssertTrue([viewController isKindOfClass:UIViewController.class]);
}

- (void)testFormViewControllerWithScreenshot_shouldReturnUIViewController
{
    // -- Arrange --
    UIImage *screenshot = [[UIImage alloc] init];

    // -- Act --
    UIViewController *viewController =
        [SentryObjCSDK.feedback formViewControllerWithScreenshot:screenshot];

    // -- Assert --
    XCTAssertNotNil(viewController);
    XCTAssertTrue([viewController isKindOfClass:UIViewController.class]);
}

- (void)testFormViewControllerWithConfigure_shouldCallConfigurationCallback
{
    // -- Arrange --
    __block BOOL configureCalled = NO;

    // -- Act --
    UIViewController *viewController = [SentryObjCSDK.feedback
        formViewControllerWithConfigure:^(SentryObjCUserFeedbackConfiguration *configuration) {
            configureCalled = YES;
            configuration.animations = NO;
        }];

    // -- Assert --
    XCTAssertTrue(configureCalled);
    XCTAssertNotNil(viewController);
    XCTAssertTrue([viewController isKindOfClass:UIViewController.class]);
}

- (void)testFormViewControllerWithScreenshotAndConfigure_shouldCallConfigurationCallback
{
    // -- Arrange --
    UIImage *screenshot = [[UIImage alloc] init];
    __block BOOL configureCalled = NO;

    // -- Act --
    UIViewController *viewController = [SentryObjCSDK.feedback
        formViewControllerWithScreenshot:screenshot
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
