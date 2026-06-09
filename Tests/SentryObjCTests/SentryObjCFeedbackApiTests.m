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

@end

#endif
