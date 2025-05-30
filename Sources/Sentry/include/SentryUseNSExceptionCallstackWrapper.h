#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#if TARGET_OS_OSX

@class SentryThread;

@protocol ExceptionProtocol <NSObject>
- (NSString *)name;
- (NSString *)reason;
- (NSDictionary *)userInfo;
- (NSArray<NSNumber *> *)callStackReturnAddresses;
@end

@interface NSException (ExceptionProtocol) <ExceptionProtocol>
@end

/**
 * This is a helper class to identify exceptions that should use the stacktrace within
 */
@interface SentryUseNSExceptionCallstackWrapper : NSException

- (instancetype)initWithException:(NSObject<ExceptionProtocol> *)exception;
- (NSArray<SentryThread *> *)buildThreads;

@end

#endif // TARGET_OS_OSX

NS_ASSUME_NONNULL_END
