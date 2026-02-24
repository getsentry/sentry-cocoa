#import <Foundation/Foundation.h>

#if TARGET_OS_OSX && !SENTRY_NO_UI_FRAMEWORK

@interface SentryCrashExceptionApplicationHelper : NSObject
+ (void)reportException:(NSException *)exception;
@end
#endif
