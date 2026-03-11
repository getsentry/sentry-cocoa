#import <Foundation/Foundation.h>

#if TARGET_OS_OSX && !SENTRY_NO_UI_FRAMEWORK

@interface SentryNSExceptionCaptureHelper : NSObject

/// Captures the exception and marks that we are inside reportException:.
/// Call this from -[NSApplication reportException:] before calling super.
+ (void)reportException:(NSException *)exception;

/// Called after [super reportException:] returns.
+ (void)reportExceptionDidFinish;

/// Captures the exception only if not already captured by reportException:.
/// Call this from -[NSApplication _crashOnException:].
+ (void)crashOnException:(NSException *)exception;

@end
#endif
