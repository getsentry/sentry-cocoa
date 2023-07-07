#import "SentryProfilerMocksSwiftCompatible.h"
#import "SentryProfilerMocks.h"
#import "SentryProfilerState.h"
#include <vector>

using namespace std;

void
appendMockBacktrace(SentryProfilingState *state, uint64_t threadID, const int threadPriority,
    const char *_Nullable threadName, uint64_t queueAddress, const char *queueLabel,
    NSArray<NSNumber *> *addresses)
{

    auto backtraceAddresses = std::vector<std::uintptr_t>();

    for (NSNumber *address in addresses) {
        backtraceAddresses.push_back(address.unsignedLongLongValue);
    }

    const auto backtrace = mockBacktrace(
        threadID, threadPriority, threadName, queueAddress, queueLabel, backtraceAddresses);
    [state appendBacktrace:backtrace];
}

@implementation SentryProfilerMocksSwiftCompatible

@end
