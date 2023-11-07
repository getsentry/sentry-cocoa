#import "SentryCrash.h"
#import "SentryCrashCachedData.h"
#import "SentryCrashInstallation+Private.h"
#import "SentryCrashInstallation.h"
#import "SentryCrashMonitor.h"
#import "SentryCrashMonitor_MachException.h"
#import "SentryCrashSystemCapabilities.h"
#import "SentryDependencyContainer.h"
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

@property (nonatomic, strong) TestNSNotificationCenterWrapper *notificationCenter;

@end

@implementation SentryCrashInstallationTests

- (void)tearDown
{
    [super tearDown];
    [SentryDependencyContainer reset];
}

#pragma mark - Tests

- (void)testUninstall
{
    SentryCrashTestInstallation *installation = [self getSut];

    [installation install];

    SentryCrashMonitorType monitorsAfterInstall
        = SentryDependencyContainer.sharedInstance.crashReporter.monitoring;

    [installation uninstall];

    [self assertUninstalled:installation monitorsAfterInstall:monitorsAfterInstall];
}

- (void)testUninstall_CallsRemoveObservers
{
    SentryCrashTestInstallation *installation = [self getSut];

    [installation install];
    [installation uninstall];

#if SENTRY_UIKIT_AVAILABLE
    XCTAssertEqual(5, self.notificationCenter.removeObserverWithNameInvocationsCount);
#endif // SENTRY_UIKIT_AVAILABLE
}

- (void)testUninstall_Install
{
    SentryCrashTestInstallation *installation = [self getSut];

    [installation install];

    SentryCrashMonitorType monitorsAfterInstall
        = SentryDependencyContainer.sharedInstance.crashReporter.monitoring;
    CrashHandlerData *crashHandlerDataAfterInstall = [installation g_crashHandlerData];

    // To ensure multiple calls in a row work
    for (int i = 0; i < 10; i++) {
        [installation uninstall];
        [installation install];
    }

    [self assertReinstalled:installation
                monitorsAfterInstall:monitorsAfterInstall
        crashHandlerDataAfterInstall:crashHandlerDataAfterInstall];

    [installation uninstall];
    [self assertUninstalled:installation monitorsAfterInstall:monitorsAfterInstall];

    [installation install];
    [self assertReinstalled:installation
                monitorsAfterInstall:monitorsAfterInstall
        crashHandlerDataAfterInstall:crashHandlerDataAfterInstall];

#if SentryCrashCRASH_HAS_UIAPPLICATION
    XCTAssertEqual(55, self.notificationCenter.removeObserverWithNameInvocationsCount);
#endif // SentryCrashCRASH_HAS_UIAPPLICATION
}

#pragma mark - Private

- (SentryCrashTestInstallation *)getSut
{
    SentryCrashTestInstallation *installation =
        [[SentryCrashTestInstallation alloc] initForTesting];
    self.notificationCenter = [[TestNSNotificationCenterWrapper alloc] init];
    [SentryDependencyContainer.sharedInstance.crashReporter
        setSentryNSNotificationCenterWrapper:self.notificationCenter];
    return installation;
}

- (void)assertReinstalled:(SentryCrashTestInstallation *)installation
            monitorsAfterInstall:(SentryCrashMonitorType)monitorsAfterInstall
    crashHandlerDataAfterInstall:(CrashHandlerData *)crashHandlerDataAfterInstall
{
    SentryCrash *sentryCrash = SentryDependencyContainer.sharedInstance.crashReporter;
    XCTAssertNotEqual(NULL, [installation g_crashHandlerData]);
    XCTAssertEqual(monitorsAfterInstall, sentryCrash.monitoring);
    XCTAssertEqual(monitorsAfterInstall, sentrycrashcm_getActiveMonitors());
    XCTAssertNotEqual(NULL, sentryCrash.onCrash);
    XCTAssertEqual(crashHandlerDataAfterInstall, [installation g_crashHandlerData]);
    XCTAssertNotEqual(NULL, sentrycrashcm_getEventCallback());
    XCTAssertTrue(sentrycrashccd_hasThreadStarted());

    [self assertReservedThreads:monitorsAfterInstall];
}

- (void)assertUninstalled:(SentryCrashTestInstallation *)installation
     monitorsAfterInstall:(SentryCrashMonitorType)monitorsAfterInstall
{
    SentryCrash *sentryCrash = SentryDependencyContainer.sharedInstance.crashReporter;
    XCTAssertEqual(NULL, [installation g_crashHandlerData]);
    XCTAssertEqual(SentryCrashMonitorTypeNone, sentryCrash.monitoring);
    XCTAssertEqual(SentryCrashMonitorTypeNone, sentrycrashcm_getActiveMonitors());
    XCTAssertEqual(NULL, sentryCrash.onCrash);
    XCTAssertEqual(NULL, sentrycrashcm_getEventCallback());
    XCTAssertFalse(sentrycrashccd_hasThreadStarted());

    [self assertReservedThreads:monitorsAfterInstall];
}

/**
 * SentryCrash only fills the reserved threads list if the mach exception monitor is enabled.
 */
- (void)assertReservedThreads:(SentryCrashMonitorType)monitorsAfterInstall
{
    if (monitorsAfterInstall & SentryCrashMonitorTypeMachException) {
        XCTAssertTrue(sentrycrashcm_hasReservedThreads());
    } else {
        XCTAssertFalse(sentrycrashcm_hasReservedThreads());
    }
}

@end

NS_ASSUME_NONNULL_END
