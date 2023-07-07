#import <Foundation/Foundation.h>

@class SentryProfilingState;

NS_ASSUME_NONNULL_BEGIN

void appendMockBacktrace(SentryProfilingState *state, uint64_t threadID, const int threadPriority,
    const char *_Nullable threadName, uint64_t queueAddress, const char *queueLabel,
    NSArray<NSNumber *> *addresses);

@interface SentryProfilerMocksSwiftCompatible : NSObject

@end

NS_ASSUME_NONNULL_END
