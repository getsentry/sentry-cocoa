#if !SDK_V10
#    import "SentryCrashMonitor_CPPException.h"
#    include "SentryTestUtilsObjCpp-SDKHeaders.h"
#    import <XCTest/XCTest.h>

#    include <atomic>
#    include <mach/mach.h>
#    include <pthread.h>
#    include <stdexcept>
#    include <thread>
#    include <unistd.h>

struct ConcurrentThrowState {
    std::atomic<bool> shouldThrow { false };
    std::atomic<bool> didThrow { false };
    uintptr_t stackAddress = 0;
};

// Observe suspension without taking a dyld lock or waiting for the suspended thread. This
// catches the ordering regression deterministically without hanging the test runner.
class SuspensionCheckingException : public std::exception {
public:
    SuspensionCheckingException(thread_t thread, ConcurrentThrowState &state)
        : thread(thread)
        , state(state)
    {
    }

    const char *
    what() const noexcept override
    {
        thread_basic_info_data_t info = { };
        mach_msg_type_number_t count = THREAD_BASIC_INFO_COUNT;

        if (thread_info(thread, THREAD_BASIC_INFO, reinterpret_cast<thread_info_t>(&info), &count)
            != KERN_SUCCESS) {
            return "thread_info failed";
        }

        if (info.suspend_count != 0) {
            return "Other thread is suspended";
        }

        // A caught exception inside what() must not replace this thread's throw-site cursor,
        // but suppression must not prevent the other thread from capturing its own throw.
        try {
            throw std::runtime_error("Caught inside what()");
        } catch (...) {
        }

        state.shouldThrow = true;

        while (!state.didThrow) {
            usleep(1000);
        }

        return "Other thread is running";
    }

private:
    thread_t thread;
    ConcurrentThrowState &state;
};

@interface SentryTestNSExceptionSubclass : NSException
@end

@implementation SentryTestNSExceptionSubclass
@end

@interface SentryCrashMonitor_CppException_Tests : XCTestCase

@end

@implementation SentryCrashMonitor_CppException_Tests

bool terminateCalled = false;
SentryCrashMonitorAPI *api;
NSString *capturedExceptionContextCrashReason;
SentryCrashMonitorType capturedCrashType;
uintptr_t capturedExceptionStackAddress;

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
    sentrycrashcm_resetState();
    sentrycrashcm_setEventCallback(NULL);
    capturedExceptionContextCrashReason = NULL;
    capturedCrashType = (SentryCrashMonitorType)0;
    capturedExceptionStackAddress = 0;
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
    capturedCrashType = context->crashType;

    if (context->stackCursor != NULL) {
        SentryCrashStackCursor cursor
            = *static_cast<SentryCrashStackCursor *>(context->stackCursor);
        cursor.advanceCursor(&cursor);
        capturedExceptionStackAddress = cursor.stackEntry.address;
    }

    if (context->crashReason) {
        capturedExceptionContextCrashReason = [NSString stringWithUTF8String:context->crashReason];
    }
}

- (void)testThrowNSExceptionSubclass_ShouldNotCaptureStacktrace
{
    // Arrange
    api->setEnabled(true);
    sentrycrashcm_cppexception_enable_swap_cxa_throw();

    @try {
        // Act
        [[SentryTestNSExceptionSubclass exceptionWithName:@"TestException"
                                                   reason:@"Test"
                                                 userInfo:nil] raise];
    } @catch (...) {
    }

    // Assert
    SentryCrashStackCursor stackCursor = sentrycrashcm_cppexception_getStackCursor();
    stackCursor.advanceCursor(&stackCursor);
    XCTAssertEqual(
        stackCursor.stackEntry.address, (uintptr_t)0, "Stack trace should NOT be captured.");
}

- (void)testTerminateWithNSExceptionSubclass_NotHandledByCppHandler
{
    // Arrange
    std::set_terminate(&mockTerminationHandler);
    sentrycrashcm_setEventCallback(mockHandleExceptionHandler);
    api->setEnabled(true);

    // Act
    @try {
        [[SentryTestNSExceptionSubclass exceptionWithName:@"TestException"
                                                   reason:@"Test"
                                                 userInfo:nil] raise];
    } @catch (...) {
        std::get_terminate()();
    }

    // Assert
    XCTAssertTrue(
        terminateCalled, "Original terminate handler should be called for ObjC exceptions.");
    XCTAssertNotEqual(capturedCrashType, SentryCrashMonitorTypeCPPException,
        "NSException subclass should NOT be handled by C++ exception handler.");
}

- (void)testTerminateWithArbitraryObjectiveCObject_HandledByCppHandler
{
    // Arrange
    sentrycrashcm_setEventCallback(mockHandleExceptionHandler);
    api->setEnabled(true);

    // Act
    @try {
        @throw @"Objective-C object exception";
    } @catch (...) {
        std::get_terminate()();
    }

    // Assert
    XCTAssertEqual(capturedCrashType, SentryCrashMonitorTypeCPPException,
        "Arbitrary Objective-C object throws are not handled by NSSetUncaughtExceptionHandler.");
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

- (void)testCallHandler_whenDescribingException_shouldNotSuspendOtherThreads
{
    // -- Arrange --
    std::set_terminate(&mockTerminationHandler);
    sentrycrashcm_setEventCallback(mockHandleExceptionHandler);
    api->setEnabled(true);
    sentrycrashcm_cppexception_enable_swap_cxa_throw();

    ConcurrentThrowState state;
    std::atomic<bool> ready(false);
    std::atomic<bool> finished(false);

    std::thread otherThread([&] {
        ready = true;

        while (!finished) {
            if (state.shouldThrow && !state.didThrow) {
                try {
                    throw std::runtime_error("Other thread during what()");
                } catch (...) {
                }

                SentryCrashStackCursor cursor = sentrycrashcm_cppexception_getStackCursor();
                cursor.advanceCursor(&cursor);

                state.stackAddress = cursor.stackEntry.address;
                state.didThrow = true;
            }

            usleep(1000);
        }
    });

    while (!ready) {
        usleep(1000);
    }

    thread_t thread = pthread_mach_thread_np(otherThread.native_handle());

    // -- Act --
    uintptr_t originalStackAddress = 0;

    try {
        throw SuspensionCheckingException(thread, state);
    } catch (...) {
        SentryCrashStackCursor cursor = sentrycrashcm_cppexception_getStackCursor();
        cursor.advanceCursor(&cursor);

        originalStackAddress = cursor.stackEntry.address;
        std::get_terminate()();
    }

    finished = true;
    otherThread.join();

    // -- Assert --
    XCTAssertEqual(capturedCrashType, SentryCrashMonitorTypeCPPException);
    XCTAssertEqualObjects(capturedExceptionContextCrashReason, @"Other thread is running");
    XCTAssertTrue(state.didThrow.load());
    XCTAssertNotEqual(state.stackAddress, (uintptr_t)0);
    XCTAssertNotEqual(originalStackAddress, (uintptr_t)0);
    XCTAssertEqual(capturedExceptionStackAddress, originalStackAddress);
}

- (void)testThrowCppException_whenAnotherThreadThrows_shouldPreserveCurrentThreadStacktrace
{
    // -- Arrange --
    api->setEnabled(true);
    sentrycrashcm_cppexception_enable_swap_cxa_throw();

    try {
        throw std::runtime_error("Main thread");
    } catch (...) {
    }

    SentryCrashStackCursor originalCursor = sentrycrashcm_cppexception_getStackCursor();
    originalCursor.advanceCursor(&originalCursor);

    // -- Act --
    uintptr_t otherThreadAddress = 0;

    std::thread otherThread([&] {
        try {
            throw std::runtime_error("Other thread");
        } catch (...) {
        }

        SentryCrashStackCursor cursor = sentrycrashcm_cppexception_getStackCursor();
        cursor.advanceCursor(&cursor);

        otherThreadAddress = cursor.stackEntry.address;
    });
    otherThread.join();

    SentryCrashStackCursor currentCursor = sentrycrashcm_cppexception_getStackCursor();
    currentCursor.advanceCursor(&currentCursor);

    // -- Assert --
    XCTAssertNotEqual(originalCursor.stackEntry.address, (uintptr_t)0);
    XCTAssertNotEqual(otherThreadAddress, (uintptr_t)0);
    XCTAssertNotEqual(otherThreadAddress, originalCursor.stackEntry.address);
    XCTAssertEqual(currentCursor.stackEntry.address, originalCursor.stackEntry.address);
}

- (void)testGetStackCursor_whenMonitorReenabled_shouldResetOtherThreadsCursor
{
    // -- Arrange --
    api->setEnabled(true);
    sentrycrashcm_cppexception_enable_swap_cxa_throw();

    std::atomic<bool> captured(false);
    std::atomic<bool> reenabled(false);
    uintptr_t originalAddress = 0;
    bool hasStaleFrame = true;

    std::thread otherThread([&] {
        try {
            throw std::runtime_error("Before re-enabling");
        } catch (...) {
        }

        SentryCrashStackCursor cursor = sentrycrashcm_cppexception_getStackCursor();
        cursor.advanceCursor(&cursor);

        originalAddress = cursor.stackEntry.address;

        captured = true;
        while (!reenabled) {
            usleep(1000);
        }
        cursor = sentrycrashcm_cppexception_getStackCursor();
        hasStaleFrame = cursor.advanceCursor(&cursor);
    });

    while (!captured) {
        usleep(1000);
    }

    // -- Act --
    api->setEnabled(false);
    api->setEnabled(true);
    reenabled = true;
    otherThread.join();

    // -- Assert --
    XCTAssertNotEqual(originalAddress, (uintptr_t)0);
    XCTAssertFalse(hasStaleFrame);
}

- (void)testCallHandler_whenNoActiveException_shouldCaptureTerminate
{
    // -- Arrange --
    std::set_terminate(&mockTerminationHandler);
    sentrycrashcm_setEventCallback(mockHandleExceptionHandler);
    api->setEnabled(true);

    // -- Act --
    std::get_terminate()();

    // -- Assert --
    XCTAssertEqual(capturedCrashType, SentryCrashMonitorTypeCPPException);
    XCTAssertEqualObjects(capturedExceptionContextCrashReason, @"");
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

#endif // !SDK_V10
