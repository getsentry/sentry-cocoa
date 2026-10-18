#if SDK_V10

#    import <XCTest/XCTest.h>

#    include "SentryKSCrashReportWriterCallbacks.h"

@interface SentryKSCrashReportWriterCallbacksTests : XCTestCase
@end

@implementation SentryKSCrashReportWriterCallbacksTests

- (void)setUp
{
    [super setUp];
    sentrykscrash_setReportPersistenceEnabled(false);
}

- (void)tearDown
{
    sentrykscrash_setReportPersistenceEnabled(false);
    [super tearDown];
}

- (void)testWillWriteReport_whenPersistenceIsActive_shouldPreservePlan
{
    // -- Arrange --
    sentrykscrash_setReportPersistenceEnabled(true);
    KSCrash_ExceptionHandlingPlan plan = {
        .shouldRecordAllThreads = false,
        .shouldWriteReport = true,
        .isFatal = true,
    };
    KSCrash_MonitorContext context = { 0 };

    // -- Act --
    sentrykscrash_willWriteReport(&plan, &context);

    // -- Assert --
    XCTAssertTrue(sentrykscrash_isReportPersistenceEnabled());
    XCTAssertTrue(plan.shouldWriteReport);
    XCTAssertFalse(plan.shouldRecordAllThreads);
}

- (void)testWillWriteReport_whenPersistenceIsInactive_shouldDisableReportAndThreadCollection
{
    // -- Arrange --
    KSCrash_ExceptionHandlingPlan plan = {
        .shouldRecordAllThreads = true,
        .shouldWriteReport = true,
        .isFatal = true,
    };
    KSCrash_MonitorContext context = { 0 };

    // -- Act --
    sentrykscrash_willWriteReport(&plan, &context);

    // -- Assert --
    XCTAssertFalse(sentrykscrash_isReportPersistenceEnabled());
    XCTAssertFalse(plan.shouldWriteReport);
    XCTAssertFalse(plan.shouldRecordAllThreads);
}

- (void)testWillWriteReport_whenReactivated_shouldPreserveNewPlan
{
    // -- Arrange --
    KSCrash_ExceptionHandlingPlan inactivePlan = {
        .shouldRecordAllThreads = true,
        .shouldWriteReport = true,
        .isFatal = true,
    };
    KSCrash_MonitorContext context = { 0 };
    sentrykscrash_willWriteReport(&inactivePlan, &context);

    // -- Act --
    sentrykscrash_setReportPersistenceEnabled(true);
    KSCrash_ExceptionHandlingPlan reactivatedPlan = {
        .shouldRecordAllThreads = true,
        .shouldWriteReport = true,
        .isFatal = true,
    };
    sentrykscrash_willWriteReport(&reactivatedPlan, &context);

    // -- Assert --
    XCTAssertFalse(inactivePlan.shouldWriteReport);
    XCTAssertFalse(inactivePlan.shouldRecordAllThreads);
    XCTAssertTrue(sentrykscrash_isReportPersistenceEnabled());
    XCTAssertTrue(reactivatedPlan.shouldWriteReport);
    XCTAssertTrue(reactivatedPlan.shouldRecordAllThreads);
}

- (void)testWillWriteReport_whenPlanIsNull_shouldReturnSafely
{
    // -- Arrange --
    // KSCrash's callback contract is nonnull, which Swift requires for exact function-pointer
    // assignment. This test exercises the implementation's defensive behavior outside that
    // contract.
#    ifndef __clang_analyzer__
    KSCrash_MonitorContext context = { 0 };
    void (*callback)(KSCrash_ExceptionHandlingPlan *_Nullable,
        const KSCrash_MonitorContext *_Nonnull) = sentrykscrash_willWriteReport;

    // -- Act --
    callback(NULL, &context);
#    endif

    // -- Assert --
    XCTAssertFalse(sentrykscrash_isReportPersistenceEnabled());
}

@end

#endif // SDK_V10
