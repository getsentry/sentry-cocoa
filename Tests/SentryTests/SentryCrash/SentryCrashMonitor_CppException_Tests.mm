#include "SentryCrashMonitorContext.h"
#import "SentryCrashMonitor_CPPException.h"
#import <XCTest/XCTest.h>

#include <iostream>
#include <stdexcept>

@interface SentryCrashMonitor_CppException_Tests : XCTestCase

@end

@implementation SentryCrashMonitor_CppException_Tests

bool terminateCalled = false;
SentryCrashMonitorAPI *api;
NSString *capturedExceptionContextCrashReason;

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

- (void)tearDown
{
    [super tearDown];

    if (api != NULL) {
        api->setEnabled(false);
    }
    sentrycrashcm_setEventCallback(NULL);
    capturedExceptionContextCrashReason = NULL;
}

- (void)testCallTerminationHandler_NotEnabled
{
    // -- Arrange --
    std::set_terminate(&testTerminationHandler);

    api = sentrycrashcm_cppexception_getAPI();

    // -- Act --
    sentrycrashcm_cppexception_callOriginalTerminationHandler();

    // -- Assert --
    XCTAssertFalse(terminateCalled);
}

- (void)testCallTerminationHandler_Enabled
{
    // -- Arrange --
    std::set_terminate(&testTerminationHandler);

    api = sentrycrashcm_cppexception_getAPI();
    api->setEnabled(true);

    // -- Act --
    sentrycrashcm_cppexception_callOriginalTerminationHandler();

    // -- Assert
    XCTAssertTrue(terminateCalled);
}

void
testHandleExceptionHandler(struct SentryCrash_MonitorContext *context)
{
    if (!context) {
        XCTFail("Received null context in handler");
        return;
    }
    capturedExceptionContextCrashReason = [NSString stringWithUTF8String:context->crashReason];
}

- (void)testCallHandler_shouldCaptureExceptionDescription
{
    // -- Arrange --
    sentrycrashcm_setEventCallback(testHandleExceptionHandler);
    api = sentrycrashcm_cppexception_getAPI();

    // -- Act --
    api->setEnabled(true);
    try {
        throw std::runtime_error("Example Error");
    } catch (...) {
        // This exception handler sets the error context of the termination handler
        // Instead of rethrowing, directly call the termination handler
        std::get_terminate()();
    }

    // -- Assert --
    NSString *errorMessage = @"Example Error";
    XCTAssertEqual(capturedExceptionContextCrashReason.length, errorMessage.length);
    XCTAssertEqualObjects(capturedExceptionContextCrashReason, errorMessage);
}

- (void)testCallHandler_descriptionExactLengthOfBuffer_shouldCaptureTruncatedExceptionDescription
{
    // -- Arrange --
    sentrycrashcm_setEventCallback(testHandleExceptionHandler);
    api = sentrycrashcm_cppexception_getAPI();

    // Build a 1000 + 1 character message
    NSString *errorMessage = [@"" stringByPaddingToLength:1000 withString:@"A" startingAtIndex:0];

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
    // Due to the nature of C strings, the last character of the buffer will be a null terminator
    NSString *truncatedErrorMessage = [@"" stringByPaddingToLength:999
                                                        withString:@"A"
                                                   startingAtIndex:0];
    XCTAssertEqual(capturedExceptionContextCrashReason.length, truncatedErrorMessage.length);
    XCTAssertEqualObjects(capturedExceptionContextCrashReason, truncatedErrorMessage);
}

- (void)testCallHandler_descriptionLongerThanBuffer_shouldCaptureTruncatedExceptionDescription
{
    // -- Arrange --
    sentrycrashcm_setEventCallback(testHandleExceptionHandler);
    api = sentrycrashcm_cppexception_getAPI();

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
    // Due to the nature of C strings, the last character of the buffer will be a null terminator
    NSString *truncatedErrorMessage = [@"" stringByPaddingToLength:999
                                                        withString:@"A"
                                                   startingAtIndex:0];
    XCTAssertEqual(capturedExceptionContextCrashReason.length, truncatedErrorMessage.length);
    XCTAssertEqualObjects(capturedExceptionContextCrashReason, truncatedErrorMessage);
}
@end
