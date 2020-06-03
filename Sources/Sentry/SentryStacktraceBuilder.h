#import <Foundation/Foundation.h>

@class SentryStacktrace;

NS_ASSUME_NONNULL_BEGIN

/** Uses SentryCrash internally to retrieve the stacktrace.
 */
@interface SentryStacktraceBuilder : NSObject

- (SentryStacktrace *)buildStacktraceForCurrentThread;

@end

NS_ASSUME_NONNULL_END
