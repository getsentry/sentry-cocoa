#import "SentryProfilerMocksSwiftCompatible.h"
#import "SentryProfilerMocks.h"
#import "SentryProfilerState+ObjCpp.h"
#include <vector>

using namespace std;

@implementation SentryProfilerMocksSwiftCompatible

+ (void)appendMockBacktraceToState:(SentryProfilerState *)state
                          threadID:(uint64_t)threadID
                    threadPriority:(const int)threadPriority
                        threadName:(nullable NSString *)threadName
                      queueAddress:(uint64_t)queueAddress
                        queueLabel:(NSString *)queueLabel
                         addresses:(NSArray<NSNumber *> *)addresses
{
    auto backtraceAddresses = std::vector<std::uintptr_t>();

    for (NSNumber *address in addresses) {
        backtraceAddresses.push_back(address.unsignedLongLongValue);
    }

    const auto backtrace = mockBacktrace(threadID, threadPriority,
        [threadName cStringUsingEncoding:NSUTF8StringEncoding], queueAddress,
        [queueLabel cStringUsingEncoding:NSUTF8StringEncoding], backtraceAddresses);
    [state appendBacktrace:backtrace];
}

@end
