#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Helper to run a block inside an Objective-C `@try`/`@catch`.
///
/// Swift cannot catch Objective-C exceptions. Some system frameworks (notably Core Animation)
/// raise `NSException`s from code paths the SDK has to touch — for example resolving a layer's
/// presentation layer while a malformed `CABasicAnimation` is running raises
/// `-[NSConcreteValue doubleValue]: unrecognized selector`. When such an exception unwinds through
/// Swift frames it force-kills the host app. This helper lets Swift callers run the risky access
/// inside an Objective-C exception handler so they can degrade gracefully instead of crashing.
///
/// See https://github.com/getsentry/sentry-cocoa/issues/7810 for context.
@interface SentryObjCExceptionHelper : NSObject

/// Executes `block` inside an Objective-C `@try`/`@catch`.
///
/// - Parameter block: The block to execute. It is run synchronously before this method returns.
/// - Parameter name: The name of the exception to catch.
/// - Parameter reasonPrefix: The prefix of the exception reason to catch.
/// - Returns: `YES` if `block` completed without raising an `NSException`, `NO` if a matching
///   exception was caught and swallowed. Non-matching exceptions are rethrown.
+ (BOOL)tryBlock:(NS_NOESCAPE void (^)(void))block
    catchingExceptionWithName:(NSExceptionName)name
                 reasonPrefix:(NSString *)reasonPrefix
    NS_SWIFT_NAME(tryBlock(_:catchingExceptionWithName:reasonPrefix:));

@end

NS_ASSUME_NONNULL_END
