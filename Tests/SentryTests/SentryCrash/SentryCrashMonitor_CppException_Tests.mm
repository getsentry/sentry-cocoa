#include "SentryCrashCxaThrowSwapper.h"
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
mockTerminationHandler(void)
{
    terminateCalled = true;
}

- (void)setUp
{
    [super setUp];
    terminateCalled = false;

    api = sentrycrashcm_cppexception_getAPI();
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
    std::set_terminate(&mockTerminationHandler);

    // -- Act --
    sentrycrashcm_cppexception_callOriginalTerminationHandler();

    // -- Assert --
    XCTAssertFalse(terminateCalled);
}

- (void)testCallTerminationHandler_Enabled
{
    // -- Arrange --
    std::set_terminate(&mockTerminationHandler);
    api->setEnabled(true);

    // -- Act --
    sentrycrashcm_cppexception_callOriginalTerminationHandler();

    // -- Assert
    XCTAssertTrue(terminateCalled);
}

- (void)testSetDisabled_UnswapsCxaThrow
{
    // Arrange
    api->setEnabled(true);
    sentrycrashcm_cppexception_enable_swap_cxa_throw();

    // Act
    api->setEnabled(false);

    // Assert
    XCTAssertFalse(
        sentrycrashct_is_cxa_throw_swapped(), "Disabling the monitor must unswap cxa_throw.");
}

- (void)testThrowCppException_CapturesStacktrace
{
    // Arrange
    api->setEnabled(true);
    sentrycrashcm_cppexception_enable_swap_cxa_throw();

    try {
        // Act
        throw std::invalid_argument("Invalid Argument.");
    } catch (...) {
    }

    // Assert
    SentryCrashStackCursor stackCursor = sentrycrashcm_cppexception_getStackCursor();
    stackCursor.advanceCursor(&stackCursor);
    XCTAssertTrue(stackCursor.stackEntry.address > 0, "Stack trace should be captured.");
}

- (void)testThrowNSException_DoesNotCapturesStacktrace
{
    // Arrange
    api->setEnabled(true);
    sentrycrashcm_cppexception_enable_swap_cxa_throw();

    @try {
        // Act
        [NSException raise:NSInvalidArgumentException format:@"Invalid Argument."];
    } @catch (...) {
    }

    // Assert
    SentryCrashStackCursor stackCursor = sentrycrashcm_cppexception_getStackCursor();
    stackCursor.advanceCursor(&stackCursor);
    XCTAssertEqual(
        stackCursor.stackEntry.address, (uintptr_t)0, "Stack trace should NOT be captured.");
}

void
mockHandleExceptionHandler(struct SentryCrash_MonitorContext *context)
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
    sentrycrashcm_setEventCallback(mockHandleExceptionHandler);
    api->setEnabled(true);

    // -- Act --
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
    sentrycrashcm_setEventCallback(mockHandleExceptionHandler);
    api->setEnabled(true);

    // Build a 1000 character message
    NSString *errorMessage = [@"" stringByPaddingToLength:1000 withString:@"A" startingAtIndex:0];

    // -- Act --
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
    sentrycrashcm_setEventCallback(mockHandleExceptionHandler);
    api->setEnabled(true);

    // Build a 1000 character message, with a single character overflow.
    // The overflow character is different, so that we can verify truncation at the end
    NSString *errorMessage = [[@"" stringByPaddingToLength:1000 withString:@"A"
                                           startingAtIndex:0] stringByAppendingString:@"B"];

    // -- Act --
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
