// TEMPORARY — DELETE BEFORE MERGING GH-8548, together with the iOS 15 suite in
// .sauce/benchmarking-config.yml, the workflow_dispatch input in
// .github/workflows/benchmarking.yml, and the gh1355-old-ordering branch in
// SentryUIViewControllerSwizzlingHelper.m.
//
// GH-1355 (the convenience-initializer crash behind removing init swizzling in GH-1361) was only
// ever reported on iOS 15.0, on physical devices, in Release/TestFlight builds. iOS 15.0 cannot be
// installed as a simulator on current macOS hosts, and the crash never reproduced on any simulator
// we could run, so the deferred-swizzling funnel has never been checked against real iOS 15
// hardware.
//
// This lives in the iOS-Benchmarking target because that target already builds, signs and runs the
// iOS-Swift sample on real SauceLabs devices. It launches the same sample app with a launch
// argument that switches the funnel to the pre-GH-1361 ordering, then drives the
// ConvenienceInitViewController fixture. A crash here is the red proof that has been missing since
// 2021; a pass narrows the remaining uncertainty to iOS 15.0 exactly.

#import <XCTest/XCTest.h>

@interface GH1355OldOrderingTests : XCTestCase
@end

@implementation GH1355OldOrderingTests

static NSString *const kOldOrderingArg
    = @"--io.sentry.uiviewcontroller-tracing.gh1355-old-ordering";

- (void)setUp
{
    self.continueAfterFailure = NO;
    [[XCUIDevice sharedDevice] setOrientation:UIDeviceOrientationPortrait];
}

- (XCUIApplication *)launchAppWithOldOrdering
{
    XCUIApplication *app = [[XCUIApplication alloc] init];
    app.launchArguments = [app.launchArguments arrayByAddingObject:kOldOrderingArg];
    [app launch];
    return app;
}

/// The app must survive launch with the crash-inducing ordering active. Every view controller
/// created during startup runs through the funnel in the old order.
- (void)testAppLaunchesUnderOldOrdering
{
    XCUIApplication *app = [self launchAppWithOldOrdering];
    XCTAssertTrue([app.tabBars[@"Tab Bar"] waitForExistenceWithTimeout:30],
        @"The app did not reach its main screen under the pre-GH-1361 swizzle ordering.");
}

/// Opens the GH-1355 fixture (UITableViewController, convenience init -> custom designated init ->
/// super.init(style:), no @objc) twice. Reporters crashed on the SECOND instance, where the
/// initializer runs through an already-mutated method list.
- (void)testConvenienceInitFixtureUnderOldOrdering
{
    XCUIApplication *app = [self launchAppWithOldOrdering];
    XCTAssertTrue([app.tabBars[@"Tab Bar"] waitForExistenceWithTimeout:30], @"No main screen.");

    XCUIElement *extraTab = app.tabBars[@"Tab Bar"].buttons[@"Extra"];
    XCTAssertTrue([extraTab waitForExistenceWithTimeout:15], @"Extra tab not found.");
    [extraTab tap];

    for (NSUInteger attempt = 1; attempt <= 2; attempt++) {
        XCUIElement *openButton = app.buttons[@"ConvenienceInit #1355"];
        XCTAssertTrue([openButton waitForExistenceWithTimeout:15],
            @"ConvenienceInit button missing on attempt %lu.", (unsigned long)attempt);
        [openButton tap];

        XCUIElement *screen = app.staticTexts[@"convenienceInitScreen"];
        XCTAssertTrue([screen waitForExistenceWithTimeout:15],
            @"ConvenienceInit screen did not appear on attempt %lu — the app likely crashed.",
            (unsigned long)attempt);

        [app.navigationBars.buttons.firstMatch tap];
    }

    XCTAssertTrue(app.state == XCUIApplicationStateRunningForeground,
        @"The app is no longer running after exercising the GH-1355 fixture.");
}

@end
