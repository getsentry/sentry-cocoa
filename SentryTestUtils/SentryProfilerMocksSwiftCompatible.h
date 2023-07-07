#import <Foundation/Foundation.h>

@class SentryProfilerState;

NS_ASSUME_NONNULL_BEGIN

/**
 * This delivers a wrapper around the C++ function to create a mock backtrace for incorporation into
 * profiler state that can be called from Swift tests.
 */
@interface SentryProfilerMocksSwiftCompatible : NSObject

+ (void)appendMockBacktraceToState:(SentryProfilerState *)state
                          threadID:(uint64_t)threadID
                    threadPriority:(const int)threadPriority
                        threadName:(nullable NSString *)threadName
                      queueAddress:(uint64_t)queueAddress
                        queueLabel:(NSString *)queueLabel
                         addresses:(NSArray<NSNumber *> *)addresses;

@end

NS_ASSUME_NONNULL_END
