#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#if TARGET_OS_OSX

@class SentryThread;

/**
 * This is a helper class to identify exceptions that should use the stacktrace within
 */
@interface SentryExceptionWrapper : NSException

- (instancetype)initWithException:(NSException *)exception;
- (NSArray<SentryThread *> *)buildThreads;

@end

#endif

NS_ASSUME_NONNULL_END
