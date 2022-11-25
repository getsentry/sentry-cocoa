#import "SentryCrash.h"
#import "SentryCrashCachedData.h"
#import "SentryCrashInstallation+Private.h"
#import "SentryCrashInstallation.h"
#import "SentryCrashMachineContext.h"
#import "SentryCrashMonitor.h"
#import "SentryNSNotificationCenterWrapper.h"
#import "SentryTests-Swift.h"
#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryCrashTestInstallation : SentryCrashInstallation

@end

@implementation SentryCrashTestInstallation

- (instancetype)initForTesting
{
    if (self = [super initWithRequiredProperties:[NSArray new]]) { }
    return self;
}

@end

@interface SentryCrashInstallationTests : XCTestCase

@end

@implementation SentryCrashInstallationTests

- (SentryCrashTestInstallation *)getSut
{
    SentryCrashTestInstallation *installation =
        [[SentryCrashTestInstallation alloc] initForTesting];
    TestNSNotificationCenterWrapper *wrapper = [[TestNSNotificationCenterWrapper alloc] init];
    [[SentryCrash sharedInstance] setSentryNSNotificationCenterWrapper:wrapper];
    return installation;
}

- (void)testUninstall
{
    SentryCrashTestInstallation *installation = [self getSut];

    [installation install];
    [installation uninstall];

    [self assertUninstalled:installation];
}

- (void)testUninstall_BeforeInstall
{
    SentryCrashTestInstallation *installation = [self getSut];
    [installation uninstall];

    [self assertUninstalled:installation];
}

- (void)testUninstall_Install
{
    SentryCrashTestInstallation *installation = [self getSut];

    [installation install];

    SentryCrash *sentryCrash = [SentryCrash sharedInstance];
    SentryCrashMonitorType monitorsAfterInstall = sentryCrash.monitoring;
    CrashHandlerData *crashHandlerDataAfterInstall = [installation g_crashHandlerData];

    // To ensure multiple calls in a row work
    for (int i = 0; i < 20; i++) {
        [installation uninstall];
        [installation install];
    }

    [self assertReinstalled:installation
                monitorsAfterInstall:monitorsAfterInstall
        crashHandlerDataAfterInstall:crashHandlerDataAfterInstall];

    [installation uninstall];
    [self assertUninstalled:installation];

    [installation install];
    [self assertReinstalled:installation
                monitorsAfterInstall:monitorsAfterInstall
        crashHandlerDataAfterInstall:crashHandlerDataAfterInstall];
}

- (void)assertReinstalled:(SentryCrashTestInstallation *)installation
            monitorsAfterInstall:(SentryCrashMonitorType)monitorsAfterInstall
    crashHandlerDataAfterInstall:(CrashHandlerData *)crashHandlerDataAfterInstall
{
    SentryCrash *sentryCrash = [SentryCrash sharedInstance];
    XCTAssertNotEqual(NULL, [installation g_crashHandlerData]);
    XCTAssertEqual(monitorsAfterInstall, sentryCrash.monitoring);
    XCTAssertEqual(monitorsAfterInstall, sentrycrashcm_getActiveMonitors());
    XCTAssertNotEqual(NULL, sentryCrash.onCrash);
    XCTAssertEqual(crashHandlerDataAfterInstall, [installation g_crashHandlerData]);
    XCTAssertNotEqual(NULL, sentrycrashcm_getEventCallback());
    XCTAssertTrue(sentrycrashccd_hasThreadStarted());

    // SentryCrash only fills the reserved threads list if the mach exception monitor is enabled.
    SentryCrashMonitorType type = sentrycrashcm_getActiveMonitors();
    if (type & SentryCrashMonitorTypeMachException) {
        XCTAssertFalse(sentrycrashmc_isReservedThreadsEmpty());
    } else {
        XCTAssertTrue(sentrycrashmc_isReservedThreadsEmpty());
    }
}

- (void)assertUninstalled:(SentryCrashTestInstallation *)installation
{
    SentryCrash *sentryCrash = [SentryCrash sharedInstance];
    XCTAssertEqual(NULL, [installation g_crashHandlerData]);
    XCTAssertEqual(SentryCrashMonitorTypeNone, sentryCrash.monitoring);
    XCTAssertEqual(SentryCrashMonitorTypeNone, sentrycrashcm_getActiveMonitors());
    XCTAssertEqual(NULL, sentryCrash.onCrash);
    XCTAssertEqual(NULL, sentrycrashcm_getEventCallback());
    XCTAssertFalse(sentrycrashccd_hasThreadStarted());
    XCTAssertTrue(sentrycrashmc_isReservedThreadsEmpty());
}

@end

NS_ASSUME_NONNULL_END
