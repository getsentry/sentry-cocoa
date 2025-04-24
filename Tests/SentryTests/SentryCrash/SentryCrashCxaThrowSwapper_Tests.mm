#include "SentryCompiler.h"
#import "SentryCrashCxaThrowSwapper.h"
#import <XCTest/XCTest.h>
#import <chrono>
#import <dlfcn.h>
#import <exception>
#import <stdexcept>
#import <vector>

@interface SentryCrashCxaThrowSwapper_Tests : XCTestCase

@end

// Define a block type for the exception handler
typedef void (^ExceptionHandlerBlock)(NSString *exceptionWhat, NSString *typeInfoName);

static ExceptionHandlerBlock g_exceptionHandlerBlock = nil;
static int g_exceptionHandlerInvocations = 0;

static NEVER_INLINE void
testExceptionHandler(
    void *thrown_exception, std::type_info *tinfo, void (*)(void *)) KEEP_FUNCTION_IN_STACKTRACE
{
    g_exceptionHandlerInvocations++;

    if (tinfo != nullptr && thrown_exception != nullptr && g_exceptionHandlerBlock != nil) {
        std::exception *exception = static_cast<std::exception *>(thrown_exception);
        NSString *errorMessage = [NSString stringWithUTF8String:exception->what()];

        NSString *typeName = [NSString stringWithCString:tinfo->name()
                                                encoding:NSUTF8StringEncoding];

        g_exceptionHandlerBlock(errorMessage, typeName);
    }

    THWART_TAIL_CALL_OPTIMISATION
}

@implementation SentryCrashCxaThrowSwapper_Tests

- (void)tearDown
{
    [super tearDown];
    g_exceptionHandlerBlock = nil;
    g_exceptionHandlerInvocations = 0;
    sentrycrashct_unswap_cxa_throw();
}

- (void)testSwapCxaThrowHandler_RuntimeError
{
    // Arrange
    XCTestExpectation *expectation = [self expectationWithDescription:@"Exception handler called"];
    expectation.expectedFulfillmentCount = 2;

    g_exceptionHandlerBlock = ^(NSString *exceptionWhat, NSString *typeInfoName) {
        // The type name should be "St13runtime_error" or similar (mangled C++ name)
        XCTAssertTrue([typeInfoName containsString:@"runtime_error"]);
        XCTAssertEqualObjects(exceptionWhat, @"Runtime errrrrrorrrr!");

        [expectation fulfill];
    };

    sentrycrashct_swap_cxa_throw(testExceptionHandler);

    // Act
    try {
        throw std::runtime_error("Runtime errrrrrorrrr!");
    } catch (...) {
        [expectation fulfill];
    }

    // Assert
    [self waitForExpectations:@[ expectation ] timeout:1.0];
}

- (void)testSwapCxaThrowHandler_ObjCTryCatch_InvalidArgument
{
    // Arrange
    XCTestExpectation *expectation = [self expectationWithDescription:@"Exception handler called"];
    expectation.expectedFulfillmentCount = 2;

    g_exceptionHandlerBlock = ^(NSString *exceptionWhat, NSString *typeInfoName) {
        // The type name should be "St16invalid_argument" or similar (mangled C++ name)
        XCTAssertTrue([typeInfoName containsString:@"invalid_argument"]);
        XCTAssertEqualObjects(exceptionWhat, @"Passed to many arguments");

        [expectation fulfill];
    };

    sentrycrashct_swap_cxa_throw(testExceptionHandler);

    // Act
    @try {
        throw std::invalid_argument("Passed to many arguments");
    } @catch (...) {
        [expectation fulfill];
    }

    // Assert
    [self waitForExpectations:@[ expectation ] timeout:1.0];
}

- (void)testSwapCxaThrowHandler_NestedTryCatchHandlers
{
    // Arrange
    XCTestExpectation *expectation = [self expectationWithDescription:@"Exception handler called"];
    expectation.expectedFulfillmentCount = 2;

    g_exceptionHandlerBlock = ^(NSString *exceptionWhat, NSString *typeInfoName) {
        // The type name should be "St16invalid_argument" or similar (mangled C++ name)
        XCTAssertTrue([typeInfoName containsString:@"invalid_argument"]);
        XCTAssertEqualObjects(exceptionWhat, @"Passed to many arguments");

        [expectation fulfill];
    };

    sentrycrashct_swap_cxa_throw(testExceptionHandler);

    // Act
    try {
        try {
            throw std::invalid_argument("Passed to many arguments");
        } catch (const std::invalid_argument &e) {
            [expectation fulfill];
        }
    } catch (...) {
        // This catch block must not be called
        [expectation fulfill];
    }

    // Assert
    [self waitForExpectations:@[ expectation ] timeout:1.0];
}

- (void)testSwapCxaThrowHandler_NestedTryCatchHandlers_Rethrow
{
    // Arrange
    XCTestExpectation *expectation = [self expectationWithDescription:@"Exception handler called"];
    expectation.expectedFulfillmentCount = 3;

    g_exceptionHandlerBlock = ^(NSString *exceptionWhat, NSString *typeInfoName) {
        // The type name should be "St16invalid_argument" or similar (mangled C++ name)
        XCTAssertTrue([typeInfoName containsString:@"invalid_argument"]);
        XCTAssertEqualObjects(exceptionWhat, @"Passed to many arguments");

        [expectation fulfill];
    };

    sentrycrashct_swap_cxa_throw(testExceptionHandler);

    // Act
    try {
        try {
            throw std::invalid_argument("Passed to many arguments");
        } catch (const std::invalid_argument &e) {
            [expectation fulfill];
            throw; // Rethrow the exception
        }
    } catch (...) {
        [expectation fulfill];
    }

    // Assert
    [self waitForExpectations:@[ expectation ] timeout:1.0];

    XCTAssertEqual(g_exceptionHandlerInvocations, 1);
}

- (void)testSwapCxaThrowHandler_NestedTryCatchHandlers_ThrowDifferentExceptions
{
    // Arrange
    XCTestExpectation *expectation = [self expectationWithDescription:@"Exception handler called"];
    expectation.expectedFulfillmentCount = 4;

    __block int invocations = 0;
    g_exceptionHandlerBlock = ^(NSString *exceptionWhat, NSString *typeInfoName) {
        // First we get the runtime error, then the invalid argument exception
        if (invocations == 0) {
            // The type name should be "St13runtime_error" or similar (mangled C++ name)
            XCTAssertTrue([typeInfoName containsString:@"runtime_error"]);
            XCTAssertEqualObjects(exceptionWhat, @"Runtime errrrrrorrrr!");
        } else {
            // The type name should be "St16invalid_argument" or similar (mangled C++ name)
            XCTAssertTrue([typeInfoName containsString:@"invalid_argument"]);
            XCTAssertEqualObjects(exceptionWhat, @"Passed to many arguments");
        }

        invocations++;
        [expectation fulfill];
    };

    sentrycrashct_swap_cxa_throw(testExceptionHandler);

    // Act
    try {
        try {
            throw std::runtime_error("Runtime errrrrrorrrr!");
        } catch (const std::runtime_error &e) {
            [expectation fulfill];
            throw std::invalid_argument("Passed to many arguments");
        }
    } catch (...) {
        [expectation fulfill];
    }

    // Assert
    [self waitForExpectations:@[ expectation ] timeout:1.0];

    XCTAssertEqual(g_exceptionHandlerInvocations, 2);
}

- (void)testSwapCxaThrowHandler_RuntimeErrorFromBGThread
{
    // Arrange
    XCTestExpectation *expectation = [self expectationWithDescription:@"Exception handler called"];
    expectation.expectedFulfillmentCount = 2;

    g_exceptionHandlerBlock = ^(NSString *exceptionWhat, NSString *typeInfoName) {
        // The type name should be "St13runtime_error" or similar (mangled C++ name)
        XCTAssertTrue([typeInfoName containsString:@"runtime_error"]);
        XCTAssertEqualObjects(exceptionWhat, @"Runtime errrrrrorrrr!");

        [expectation fulfill];
    };

    sentrycrashct_swap_cxa_throw(testExceptionHandler);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Act
        try {
            throw std::runtime_error("Runtime errrrrrorrrr!");
        } catch (...) {
            [expectation fulfill];
        }
    });

    // Assert
    [self waitForExpectations:@[ expectation ] timeout:1.0];
}

@end
