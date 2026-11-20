#if !SDK_V10
#    import <XCTest/XCTest.h>

#    import "SentryCrashMonitorContext.h"
#    import "SentryCrashMonitor_MachException.h"
#    import "SentryInternalCDefines.h"

#    if SENTRY_HAS_MACH
#        import <mach/mach.h>
#        import <sys/sysctl.h>

@interface SentryCrashMonitor_MachException_Tests : XCTestCase
@end

@implementation SentryCrashMonitor_MachException_Tests

- (void)testSetEnabled_whenEnabled_shouldRegisterIdentityProtectedBehavior
{
    // -- Arrange --
    SentryCrashMonitorAPI *api = sentrycrashcm_machexception_getAPI();
    // Rosetta rejects the identity-protected behavior, so translated processes keep the default.
    int translated = 0;
    size_t size = sizeof(translated);
    const bool isTranslated
        = sysctlbyname("sysctl.proc_translated", &translated, &size, NULL, 0) == 0
        && translated == 1;
    const exception_behavior_t expectedBehavior
        = isTranslated ? EXCEPTION_DEFAULT : EXCEPTION_IDENTITY_PROTECTED;

    // -- Act --
    api->setEnabled(true);

    // -- Assert --
    XCTAssertTrue(api->isEnabled());
    exception_mask_t masks[EXC_TYPES_COUNT];
    exception_handler_t ports[EXC_TYPES_COUNT];
    exception_behavior_t behaviors[EXC_TYPES_COUNT];
    thread_state_flavor_t flavors[EXC_TYPES_COUNT];
    mach_msg_type_number_t count = EXC_TYPES_COUNT;
    kern_return_t kr = task_get_exception_ports(
        mach_task_self(), EXC_MASK_BAD_ACCESS, masks, &count, ports, behaviors, flavors);
    XCTAssertEqual(kr, KERN_SUCCESS);
    XCTAssertEqual(count, 1u);
    XCTAssertTrue(MACH_PORT_VALID(ports[0]));
    XCTAssertEqual(behaviors[0] & ~MACH_EXCEPTION_MASK, expectedBehavior);
    XCTAssertTrue(behaviors[0] & MACH_EXCEPTION_CODES);
    mach_port_deallocate(mach_task_self(), ports[0]);

    // The handler threads stay running; disabling only stops them from handling exceptions.
    api->setEnabled(false);
}

@end
#    endif // SENTRY_HAS_MACH

#endif // !SDK_V10
