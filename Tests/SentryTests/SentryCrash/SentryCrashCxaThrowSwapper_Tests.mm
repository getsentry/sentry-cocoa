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
typedef void (^ExceptionHandlerBlock)(void *thrown_exception, NSString *typeName);

static ExceptionHandlerBlock g_exceptionHandlerBlock = nil;

static NEVER_INLINE void
testExceptionHandler(
    void *thrown_exception, std::type_info *tinfo, void (*)(void *)) KEEP_FUNCTION_IN_STACKTRACE
{
    if (tinfo != nullptr && thrown_exception != nullptr && g_exceptionHandlerBlock != nil) {
        NSString *typeName = [NSString stringWithCString:tinfo->name()
                                                encoding:NSUTF8StringEncoding];
        g_exceptionHandlerBlock(thrown_exception, typeName);
    }

    THWART_TAIL_CALL_OPTIMISATION
}

@implementation SentryCrashCxaThrowSwapper_Tests

- (void)setUp
{
    [super setUp];
    g_exceptionHandlerBlock = nil;
}

- (void)testExceptionInterception
{
    __block NSString *capturedType = nil;
    __block NSString *capturedMessage = nil;

    g_exceptionHandlerBlock = ^(void *thrown_exception, NSString *typeName) {
        capturedType = typeName;
        std::runtime_error *runtimeError = static_cast<std::runtime_error *>(thrown_exception);
        capturedMessage = [NSString stringWithUTF8String:runtimeError->what()];
    };

    sentrycrashct_swap(testExceptionHandler);

    @try {
        throw std::runtime_error("Test exception");
    } @catch (...) {
    }

    // The type name should be "St13runtime_error" or similar (mangled C++ name)
    XCTAssertTrue([capturedType containsString:@"runtime_error"]);

    // Verify the exception message
    XCTAssertEqualObjects(capturedMessage, @"Test exception");
}

@end
