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

@end

#endif
