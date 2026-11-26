#import <Foundation/Foundation.h>

#if TARGET_OS_OSX && !SENTRY_NO_UI_FRAMEWORK

NS_ASSUME_NONNULL_BEGIN

@interface SentryNSExceptionCaptureHelper : NSObject

#    if SDK_V10
/// Installs the active crash backend's fatal exception handler.
+ (void)setUncaughtExceptionHandler:(nullable NSUncaughtExceptionHandler *)uncaughtExceptionHandler
                              owner:(NSObject *)owner;

/// Clears the fatal exception handler only when it is still owned by the caller.
+ (void)clearUncaughtExceptionHandlerForOwner:(NSObject *)owner;
#    endif

/// Captures the exception and marks that we are inside reportException:.
/// Call this from -[NSApplication reportException:] before calling super.
+ (void)reportException:(NSException *)exception;

/// Called after [super reportException:] returns.
+ (void)reportExceptionDidFinish;

/// Captures the exception only if not already captured by reportException:.
/// Call this from -[NSApplication _crashOnException:].
+ (void)crashOnException:(NSException *)exception;

@end

NS_ASSUME_NONNULL_END

#endif
