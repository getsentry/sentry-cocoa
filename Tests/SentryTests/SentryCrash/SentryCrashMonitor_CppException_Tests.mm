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
    sentrycrashcm_setEventCallback(testHandleExceptionHandler);
    SentryCrashMonitorAPI *api = sentrycrashcm_cppexception_getAPI();

    NSString *errorMessage = @"Example Error";

    // -- Act --
    api->setEnabled(true);
    try {
        throw std::runtime_error(errorMessage.UTF8String);
    } catch (...) {
        // This exception handler sets the error context of the termination handler
        // Instead of rethrowing, directly call the termination handler
        std::get_terminate()();
    }

    // -- Assert --
    SentryCrash_MonitorContext *context = capturedHandleExceptionContext;

    // Cleanup
    api->setEnabled(false);
    sentrycrashcm_setEventCallback(NULL);
    capturedHandleExceptionContext = NULL;

    NSString *crashReason = [[NSString alloc] initWithUTF8String:context->crashReason];
    XCTAssertEqualObjects(crashReason, errorMessage);
}

- (void)testCallHandler_descriptionLongerThanBuffer_shouldCaptureTruncatedExceptionDescription
{
    // -- Arrange --
    sentrycrashcm_setEventCallback(testHandleExceptionHandler);
    SentryCrashMonitorAPI *api = sentrycrashcm_cppexception_getAPI();

    // Build a 1000 + 1 character message
    NSString *errorMessage = [@"" stringByPaddingToLength:(1000 + 1)
                                               withString:@"A"
                                          startingAtIndex:0];

    // -- Act --
    // Create a thread that will throw an uncaught exception
    api->setEnabled(true);
    try {
        throw std::runtime_error(errorMessage.UTF8String);
    } catch (...) {
        // This exception handler sets the error context of the termination handler
        // Instead of rethrowing, directly call the termination handler
        std::get_terminate()();
    }

    // -- Assert --
    NSString *truncatedErrorMessage = [@"" stringByPaddingToLength:1000
                                                        withString:@"A"
                                                   startingAtIndex:0];
    SentryCrash_MonitorContext *context = capturedHandleExceptionContext;

    // Cleanup
    api->setEnabled(false);
    sentrycrashcm_setEventCallback(NULL);
    capturedHandleExceptionContext = NULL;

    // Assertions
    NSString *crashReason = [[NSString alloc] initWithUTF8String:context->crashReason];
    XCTAssertEqualObjects(crashReason, truncatedErrorMessage);
}
@end
