#include "SentryCrashMonitorContext.h"
#import "SentryCrashMonitor_CPPException.h"
#import <XCTest/XCTest.h>

#include <iostream>
#include <stdexcept>

@interface SentryCrashMonitor_CppException_Tests : XCTestCase

@end

@implementation SentryCrashMonitor_CppException_Tests

bool terminateCalled = false;

void
testTerminationHandler(void)
{
    terminateCalled = true;
}

- (void)setUp
{
    [super setUp];
    terminateCalled = false;
}

- (void)testCallTerminationHandler_NotEnabled
{

    std::set_terminate(&testTerminationHandler);

    sentrycrashcm_cppexception_callOriginalTerminationHandler();

    XCTAssertFalse(terminateCalled);
}

- (void)testCallTerminationHandler_Enabled
{

    std::set_terminate(&testTerminationHandler);

    SentryCrashMonitorAPI *api = sentrycrashcm_cppexception_getAPI();
    api->setEnabled(true);

    sentrycrashcm_cppexception_callOriginalTerminationHandler();

    XCTAssertTrue(terminateCalled);

    api->setEnabled(false);
}

XCTestExpectation *waitHandleExceptionHandlerExpectation;
struct SentryCrash_MonitorContext *capturedHandleExceptionContext;

void
testHandleExceptionHandler(struct SentryCrash_MonitorContext *context)
{
    if (!context) {
        XCTFail("Received null context in handler");
        return;
    }
    capturedHandleExceptionContext = context;
    [waitHandleExceptionHandlerExpectation fulfill];
}

- (void)testCallHandler_shouldCaptureExceptionDescription
{
    // -- Arrange --
    waitHandleExceptionHandlerExpectation =
        [self expectationWithDescription:@"Wait for C++ exception"];

    sentrycrashcm_setEventCallback(testHandleExceptionHandler);
    SentryCrashMonitorAPI *api = sentrycrashcm_cppexception_getAPI();

    const char *errorMessage = "Example Error";

    // -- Act --
    // Create a thread that will throw an uncaught exception
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        api->setEnabled(true);
        try {
            throw std::runtime_error(errorMessage);
        } catch (...) {
            // Rethrowing without catching will trigger std::terminate()
            std::rethrow_exception(std::current_exception());
        }
    });

    // -- Assert --
    [self waitForExpectationsWithTimeout:5
                                 handler:^(NSError *_Nullable error) {
                                     SentryCrash_MonitorContext *context
                                         = capturedHandleExceptionContext;

                                     // Cleanup
                                     api->setEnabled(false);
                                     sentrycrashcm_setEventCallback(NULL);
                                     capturedHandleExceptionContext = NULL;

                                     // Check for expectation failures
                                     if (error) {
                                         XCTFail(@"Expectation failed with error: %@", error);
                                     }

                                     // Assertions
                                     XCTAssertTrue(strcmp(context->crashReason, errorMessage));
                                 }];
}

- (void)testCallHandler_descriptionLongerThanBuffer_shouldCaptureTruncatedExceptionDescription
{
    // -- Arrange --
    waitHandleExceptionHandlerExpectation =
        [self expectationWithDescription:@"Wait for C++ exception"];

    sentrycrashcm_setEventCallback(testHandleExceptionHandler);
    SentryCrashMonitorAPI *api = sentrycrashcm_cppexception_getAPI();

    // Build a 1000 + 1 character message
    NSString *errorMessage = [@"" stringByPaddingToLength:(1000 + 1)
                                               withString:@"A"
                                          startingAtIndex:0];

    // -- Act --
    // Create a thread that will throw an uncaught exception
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        api->setEnabled(true);
        try {
            throw std::runtime_error(errorMessage.UTF8String);
        } catch (...) {
            // Rethrowing without catching will trigger std::terminate()
            std::rethrow_exception(std::current_exception());
        }
    });

    // -- Assert --
    NSString *truncatedErrorMessage = [@"" stringByPaddingToLength:1000
                                                        withString:@"A"
                                                   startingAtIndex:0];
    [self waitForExpectationsWithTimeout:5
                                 handler:^(NSError *_Nullable error) {
                                     SentryCrash_MonitorContext *context
                                         = capturedHandleExceptionContext;

                                     // Cleanup
                                     api->setEnabled(false);
                                     sentrycrashcm_setEventCallback(NULL);
                                     capturedHandleExceptionContext = NULL;

                                     // Check for expectation failures
                                     if (error) {
                                         XCTFail(@"Expectation failed with error: %@", error);
                                     }

                                     // Assertions
                                     XCTAssertTrue(strcmp(
                                         context->crashReason, truncatedErrorMessage.UTF8String));
                                 }];
}
@end
