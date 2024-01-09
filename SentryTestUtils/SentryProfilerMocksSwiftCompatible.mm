#import "SentryProfilerMocksSwiftCompatible.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryCurrentDateProvider.h"
#    import "SentryDependencyContainer.h"
#    import "SentryProfilerMocks.h"
#    import "SentryProfilerState+ObjCpp.h"
#    include <vector>

using namespace std;

@implementation SentryProfilerMocksSwiftCompatible

+ (void)appendMockBacktraceToState:(SentryProfilerState *)state
                          threadID:(uint64_t)threadID
                    threadPriority:(const int)threadPriority
                        threadName:(nullable NSString *)threadName
                         addresses:(NSArray<NSNumber *> *)addresses
{
    auto backtraceAddresses = std::vector<std::uintptr_t>();

    for (NSNumber *address in addresses) {
        backtraceAddresses.push_back(address.unsignedLongLongValue);
    }

    auto backtrace = mockBacktrace(threadID, threadPriority,
        [threadName cStringUsingEncoding:NSUTF8StringEncoding], backtraceAddresses);
    backtrace.absoluteTimestamp = SentryDependencyContainer.sharedInstance.dateProvider.systemTime;
    [state appendBacktrace:backtrace];
}

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
