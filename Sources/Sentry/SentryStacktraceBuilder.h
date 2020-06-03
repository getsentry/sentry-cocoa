#import <Foundation/Foundation.h>

@class SentryStacktrace;

NS_ASSUME_NONNULL_BEGIN

@interface SentryStacktraceBuilder : NSObject

- (SentryStacktrace *)buildStacktraceForCurrentThread;

@end

NS_ASSUME_NONNULL_END
