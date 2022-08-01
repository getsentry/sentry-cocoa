#import <XCTest/XCTest.h>

static NSUInteger const kMaxScrollCount = 10;
static NSUInteger const kMaxConsecutiveFindCellFailures = 3;
static NSTimeInterval const kWaitForAppStateTimeout = 10.0;
static NSTimeInterval const kWaitForElementTimeout = 5.0;

@interface ProfileDataGeneratorUITest : XCTestCase
@end

@implementation ProfileDataGeneratorUITest

- (void)setUp
{
    [super setUp];
    self.continueAfterFailure = NO;
}

- (void)testGenerateProfileData
{
    CFTimeInterval const startTime = CACurrentMediaTime();
    CFTimeInterval const runDuration_seconds = 3.0 * 60.0;
    generateProfileData(5 /* nCellsPerTab */, YES /* clearState */);
    while (true) {
        if ((CACurrentMediaTime() - startTime) >= runDuration_seconds) {
            break;
        }
        if (!generateProfileData(5 /* nCellsPerTab */, NO /* clearState */)) {
            break;
        }
    }
}

/**
 * Generates profile data by interacting with UI elements in the TrendingMovies app while running a
 * Sentry transaction with profiling enabled.
 * @param nCellsPerTab The number of cells to tap on, per tab.
 * @param clearState Whether to clear filesystem state when the app starts.
 * @return Whether the operation was successful or not.
 */
BOOL
generateProfileData(NSUInteger nCellsPerTab, BOOL clearState)
{
    XCUIApplication *app = [[XCUIApplication alloc] init];
    if (clearState) {
        app.launchArguments = @[ @"--clear" ];
    }
    [app launch];
    if (![app waitForState:XCUIApplicationStateRunningForeground timeout:kWaitForAppStateTimeout]) {
        XCTFail("App failed to transition to Foreground state");
        return NO;
    }

    XCUIElement *const tabBar = app.tabBars.firstMatch;
    if (![tabBar waitForExistenceWithTimeout:kWaitForElementTimeout]) {
        XCTFail("Failed to locate tab bar");
        return NO;
    }

    for (NSUInteger t = 0; t < 3; t++) {
        XCUIElement *const tabBarButton = [tabBar.buttons elementBoundByIndex:t];
        if (![tabBarButton waitForExistenceWithTimeout:kWaitForElementTimeout]) {
            XCTFail("Failed to find tab bar button %llu", (unsigned long long)t);
            return NO;
        }

        [tabBarButton tap];

        for (NSUInteger i = 0; i < 4; i++) {
            XCUIElement *const cellElement
                = app.collectionViews
                      .cells[[NSString stringWithFormat:@"movie %llu", (unsigned long long)i]];
            if (![cellElement waitForExistenceWithTimeout:kWaitForElementTimeout]) {
                XCTFail("Failed to find the cell.");
                return NO;
            }
            [cellElement tap];

            [NSThread sleepForTimeInterval:1.0];

            XCUIElement *const backButton = [app.navigationBars.buttons elementBoundByIndex:0];
            if (![backButton waitForExistenceWithTimeout:kWaitForElementTimeout]) {
                // failed to find a back button; maybe we're still on the movie list screen
                if (![app.tabBars.firstMatch waitForExistenceWithTimeout:kWaitForElementTimeout]) {
                    XCTFail("Failed to find back button");
                    return NO;
                }
            }
            [backButton tap];
        }
    }

    [XCUIDevice.sharedDevice pressButton:XCUIDeviceButtonHome];
    // Allow some time for the data to be uploaded before the app is killed.
    [NSThread sleepForTimeInterval:5.0];

    [app terminate];
    if (![app waitForState:XCUIApplicationStateNotRunning timeout:kWaitForAppStateTimeout]) {
        XCTFail("App failed to transition to NotRunning state");
        return NO;
    }
    return YES;
}

@end
