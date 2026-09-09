#if SDK_V10

#    import <XCTest/XCTest.h>

#    include <cstring>
#    include <cxxabi.h>
#    include <dlfcn.h>
#    include <new>
#    include <stdexcept>
#    include <typeinfo>

namespace {
using CxaThrow = void (*)(void *, std::type_info *, void (*)(void *));
using CxaRethrow = void (*)(void);

static void
destroyRuntimeError(void *exception)
{
    static_cast<std::runtime_error *>(exception)->~runtime_error();
}
} // namespace

@interface SentryCxaThrowCompatibilityTests : XCTestCase
@end

@implementation SentryCxaThrowCompatibilityTests

- (void)testThrow_whenInvokingCompatibilitySymbol_shouldForwardToCxxRuntime
{
    // -- Arrange --
    auto sentryCxaThrow = reinterpret_cast<CxaThrow>(dlsym(RTLD_DEFAULT, "__sentry_cxa_throw"));
    XCTAssertNotEqual(sentryCxaThrow, nullptr);
    if (sentryCxaThrow == nullptr) {
        return;
    }

    // -- Act --
    bool caughtException = false;
    try {
        void *exception = __cxxabiv1::__cxa_allocate_exception(sizeof(std::runtime_error));
        new (exception) std::runtime_error("SentryCxaThrowCompatibilityTests");
        sentryCxaThrow(exception, const_cast<std::type_info *>(&typeid(std::runtime_error)),
            destroyRuntimeError);
    } catch (const std::runtime_error &exception) {
        caughtException = true;
        XCTAssertEqual(std::strcmp(exception.what(), "SentryCxaThrowCompatibilityTests"), 0);
    }

    // -- Assert --
    XCTAssertTrue(caughtException);
}

- (void)testRethrow_whenInvokingCompatibilitySymbol_shouldForwardToCxxRuntime
{
    // -- Arrange --
    auto sentryCxaRethrow
        = reinterpret_cast<CxaRethrow>(dlsym(RTLD_DEFAULT, "__sentry_cxa_rethrow"));
    XCTAssertNotEqual(sentryCxaRethrow, nullptr);
    if (sentryCxaRethrow == nullptr) {
        return;
    }

    // -- Act --
    bool caughtException = false;
    try {
        try {
            throw std::runtime_error("SentryCxaRethrowCompatibilityTests");
        } catch (...) {
            sentryCxaRethrow();
        }
    } catch (const std::runtime_error &exception) {
        caughtException = true;
        XCTAssertEqual(std::strcmp(exception.what(), "SentryCxaRethrowCompatibilityTests"), 0);
    }

    // -- Assert --
    XCTAssertTrue(caughtException);
}

@end

#endif // SDK_V10
