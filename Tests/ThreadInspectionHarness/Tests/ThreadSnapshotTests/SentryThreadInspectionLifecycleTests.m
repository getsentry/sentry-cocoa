#import "MachCaptureObserver.h"
#import <SentryThreadSnapshot.h>
#import <XCTest/XCTest.h>

@interface SentryThreadInspectionLifecycleTests : XCTestCase
@end

@implementation SentryThreadInspectionLifecycleTests

// One process-lifetime sequence: readiness deliberately cannot be reset after successful install.
- (void)testReadiness_whenInstallingFailingAndReinitializing_shouldOnlyCaptureWhenSafe
{
    // -- Arrange --
    XCTAssertFalse(sentryThreadInspectionCanCaptureRemote(true));
    XCTAssertTrue(sentryThreadInspectionCanCaptureRemote(false));
    sentryThreadInspectionWillInstallCrashHandler();

    // -- Act --
    beginMachCaptureObservation(MACH_PORT_NULL, MACH_PORT_NULL);
    SentryThreadSnapshotBuffer output;
    // Even a retained inspector configured with crash handling disabled must respect an active
    // installation from a newer SDK lifecycle. The policy is evaluated after enumeration.
    bool success = sentryThreadSnapshotSystemCapture(true, false, &output);
    MachCaptureObservation observation = endMachCaptureObservation();

    // -- Assert --
    XCTAssertTrue(success);
    XCTAssertGreaterThan(output.count, 0);
    XCTAssertEqual(observation.suspendAttempts, 0);
    XCTAssertFalse(sentryThreadInspectionCanCaptureRemote(true));
    XCTAssertFalse(sentryThreadInspectionCanCaptureRemote(false));
    for (size_t i = 0; i < output.count; i++) {
        XCTAssertEqual(output.threads[i].status, SentryThreadCaptureNotRequested);
    }
    sentryThreadSnapshotSystemDestroy(&output);

    sentryThreadInspectionDidInstallCrashHandler(false);
    XCTAssertFalse(sentryThreadInspectionCanCaptureRemote(true));
    XCTAssertTrue(sentryThreadInspectionCanCaptureRemote(false));

    sentryThreadInspectionWillInstallCrashHandler();
    sentryThreadInspectionDidInstallCrashHandler(true);
    XCTAssertTrue(sentryThreadInspectionCanCaptureRemote(true));
    XCTAssertTrue(sentryThreadInspectionCanCaptureRemote(false));

    // Closing the SDK does not uninstall KSCrash. A later installation attempt must not revoke
    // readiness, including when it reports that the process-lifetime recorder is already installed.
    sentryThreadInspectionWillInstallCrashHandler();
    XCTAssertTrue(sentryThreadInspectionCanCaptureRemote(true));
    sentryThreadInspectionDidInstallCrashHandler(false);
    XCTAssertTrue(sentryThreadInspectionCanCaptureRemote(true));
}

@end
