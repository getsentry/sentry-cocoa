#import <Foundation/Foundation.h>

#if TARGET_OS_OSX && !SENTRY_NO_UIKIT

@interface SentryCrashExceptionApplicationHelper : NSObject
+ (void)reportException:(NSException *)exception;
+ (void)_crashOnException:(NSException *)exception;
@end
#endif
