#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryNSTimerFactory : SENTRY_BASE_OBJECT

- (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)interval
                                    repeats:(BOOL)repeats
                                      block:(void (^)(NSTimer *timer))block;

- (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)ti
                                     target:(id)aTarget
                                   selector:(SEL)aSelector
                                   userInfo:(nullable id)userInfo
                                    repeats:(BOOL)yesOrNo;

@end

NS_ASSUME_NONNULL_END
