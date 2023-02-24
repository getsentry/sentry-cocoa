#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import <XCTest/XCTest.h>

#    import "SentryBacktrace.h"
#    import "SentryThreadHandle.h"

#    import <cmath>
#    import <dlfcn.h>
#    import <iostream>
#    import <pthread.h>
#    import <string>
#    import <thread>

using namespace sentry::profiling;

// Avoid name mangling
extern "C" {
NOT_TAIL_CALLED NEVER_INLINE std::size_t
c(std::uintptr_t *addresses, bool *reachedEndOfStackPtr, std::size_t maxDepth, std::size_t skip)
{
    auto current = ThreadHandle::current();
    return backtrace(*current, *current, addresses, current->stackBounds(), reachedEndOfStackPtr,
        maxDepth, skip);
}

NOT_TAIL_CALLED NEVER_INLINE std::size_t
b(std::uintptr_t *addresses, bool *reachedEndOfStackPtr, std::size_t maxDepth, std::size_t skip)
{
    return c(addresses, reachedEndOfStackPtr, maxDepth, skip);
}

NOT_TAIL_CALLED NEVER_INLINE std::size_t
a(std::uintptr_t *addresses, bool *reachedEndOfStackPtr, std::size_t maxDepth, std::size_t skip)
{
    return b(addresses, reachedEndOfStackPtr, maxDepth, skip);
}

[[noreturn]] NOT_TAIL_CALLED NEVER_INLINE void
cancelLoop()
{
    while (true) {
        pthread_testcancel();
    }
}

NOT_TAIL_CALLED NEVER_INLINE void
bc_c()
{
    cancelLoop();
}

NOT_TAIL_CALLED NEVER_INLINE void
bc_e()
{
    bc_c();
}

NOT_TAIL_CALLED NEVER_INLINE void
bc_d()
{
    bc_e();
}

NOT_TAIL_CALLED NEVER_INLINE void
bc_b()
{
    bc_c();
}

NOT_TAIL_CALLED NEVER_INLINE void
bc_a()
{
    bc_b();
}
}

namespace {
std::string
symbolicate(std::uintptr_t address) noexcept
{
    if (address == 0) {
        return {};
    }
    struct dl_info info;
    if (dladdr(reinterpret_cast<void *>(address), &info) == 0) {
        return {};
    }
    if (info.dli_sname == nullptr) {
        return {};
    }
    return std::string(info.dli_sname);
}

long
indexOfSymbol(const std::uintptr_t *addresses, unsigned long depth, const char *symbol)
{
    long index = -1;
    for (decltype(depth) i = 0; i < depth; i++) {
        const auto name = symbolicate(addresses[i]);
        std::cout << name << "\n";
        if (index == -1 && name == symbol) {
            index = i;
        }
    }
    return index;
}

void *
threadEntry(void *ptr)
{
    if (pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, nullptr) != 0) {
        return nullptr;
    }
    if (pthread_setcanceltype(PTHREAD_CANCEL_DEFERRED, nullptr) != 0) {
        return nullptr;
    }
    const auto fn = (void (*)(void))(ptr);
    fn();
    return nullptr;
}

/** Returns the size of a primitive array at compile time. */
template <std::size_t N, class T>
constexpr std::size_t
countof(T (&)[N])
{
    return N;
}

/** Returns the size of an std::array at compile time. */
template <class Array, std::size_t N = std::tuple_size<Array>::value>
constexpr std::size_t
countof(Array &)
{
    return N;
}
} // namespace

@interface SentryBacktraceTests : XCTestCase
@end

@implementation SentryBacktraceTests

- (void)testBacktrace
{
    std::uintptr_t addresses[128];
    std::memset(addresses, 0, countof(addresses));
    bool reachedEndOfStack = false;
    XCTAssertGreaterThanOrEqual(
        a(addresses, &reachedEndOfStack, countof(addresses), 0), static_cast<unsigned long>(3));
    XCTAssertTrue(reachedEndOfStack);

    const auto index = indexOfSymbol(addresses, countof(addresses), "c");
    XCTAssertNotEqual(index, -1);
    if (index != -1) {
        XCTAssertEqual(symbolicate(addresses[index + 1]), "b");
        XCTAssertEqual(symbolicate(addresses[index + 2]), "a");
    }
}

- (void)testBacktraceRespectsSkip
{
    std::uintptr_t addresses[128];
    std::memset(addresses, 0, countof(addresses));
    bool reachedEndOfStack = false;
    XCTAssertGreaterThanOrEqual(
        a(addresses, &reachedEndOfStack, countof(addresses), 2), static_cast<unsigned long>(3));
    XCTAssertTrue(reachedEndOfStack);

    const auto indexC = indexOfSymbol(addresses, countof(addresses), "c");
    XCTAssertEqual(indexC, -1);

    const auto indexB = indexOfSymbol(addresses, countof(addresses), "b");
    XCTAssertNotEqual(indexB, -1);
    if (indexB != -1) {
        XCTAssertEqual(symbolicate(addresses[indexB + 1]), "a");
    }
}

- (void)testBacktraceRespectsMaxDepth
{
    std::uintptr_t addresses[2];
    std::memset(addresses, 0, countof(addresses));
    addresses[1] = 0x8BADF00D;
    bool reachedEndOfStack = false;
    XCTAssertEqual(a(addresses, &reachedEndOfStack, 1, 0), static_cast<unsigned long>(1));
    XCTAssertFalse(reachedEndOfStack);
    XCTAssertEqual(addresses[1], 0x8BADF00D);
}

- (void)testCollectsMultiThreadBacktrace
{
    pthread_t thread1, thread2;
    XCTAssertEqual(
        pthread_create(&thread1, nullptr, threadEntry, reinterpret_cast<void *>(bc_a)), 0);
    XCTAssertEqual(
        pthread_create(&thread2, nullptr, threadEntry, reinterpret_cast<void *>(bc_d)), 0);

    const auto cache = std::make_shared<ThreadMetadataCache>();
    bool foundThread1 = false, foundThread2 = false;
    // Try up to 3 times.
    for (int i = 0; i < 3; i++) {
        enumerateBacktracesForAllThreads(
            [&](auto &backtrace) {
                const auto thread = backtrace.threadMetadata.threadID;
                if (thread == pthread_mach_thread_np(thread1)) {
                    const auto start = indexOfSymbol(
                        reinterpret_cast<const uintptr_t *>(backtrace.addresses.data()),
                        backtrace.addresses.size(), "bc_c");
                    std::cout << start << '\n';
                    if (start != -1 && backtrace.addresses.size() >= 3) {
                        foundThread1 = true;
                        XCTAssertEqual(symbolicate(backtrace.addresses[start]), "bc_c");
                        XCTAssertEqual(symbolicate(backtrace.addresses[start + 1]), "bc_b");
                        XCTAssertEqual(symbolicate(backtrace.addresses[start + 2]), "bc_a");
                    }
                } else if (thread == pthread_mach_thread_np(thread2)) {
                    const auto start = indexOfSymbol(
                        reinterpret_cast<const uintptr_t *>(backtrace.addresses.data()),
                        backtrace.addresses.size(), "bc_c");
                    std::cout << start << '\n';
                    if (start != -1 && backtrace.addresses.size() >= 3) {
                        foundThread2 = true;
                        XCTAssertEqual(symbolicate(backtrace.addresses[start]), "bc_c");
                        XCTAssertEqual(symbolicate(backtrace.addresses[start + 1]), "bc_e");
                        XCTAssertEqual(symbolicate(backtrace.addresses[start + 2]), "bc_d");
                    }
                }
            },
            cache);
        if (foundThread1 && foundThread2) {
            break;
        }
        std::this_thread::sleep_for(
            std::chrono::milliseconds(static_cast<long long>(std::pow(2, i + 1)) * 1000));
    }

    XCTAssertEqual(pthread_cancel(thread1), 0);
    XCTAssertEqual(pthread_join(thread1, nullptr), 0);
    XCTAssertEqual(pthread_cancel(thread2), 0);
    XCTAssertEqual(pthread_join(thread2, nullptr), 0);

    XCTAssertTrue(foundThread1);
    XCTAssertTrue(foundThread2);
}

@end

#endif
