#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

/// Options for experimental features that are subject to change or may be removed in future
/// versions.
@interface SentryObjCExperimentalOptions : NSObject

/**
 * A more reliable way to report unhandled C++ exceptions.
 *
 * This approach hooks into all instances of the @c __cxa_throw function, which provides a more
 * comprehensive and consistent exception handling across an app's runtime, regardless of the number
 * of C++ modules or how they're linked. It helps in obtaining accurate stack traces.
 *
 * @note The mechanism of hooking into @c __cxa_throw could cause issues with symbolication on iOS
 * due to caching of symbol references.
 * @warning This is an experimental feature and is therefore disabled by default.
 */
@property (nonatomic) BOOL enableUnhandledCPPExceptionsV2;

/// When enabled, the SDK uses a more efficient mechanism for detecting watchdog terminations.
@property (nonatomic) BOOL enableWatchdogTerminationsV2;

/**
 * Reduces SDK start overhead by swizzling each @c UIViewController subclass lazily, the first time
 * an instance of it is created, instead of eagerly discovering and swizzling every subclass when
 * the SDK starts.
 *
 * By default, the SDK scans loaded binary images for all @c UIViewController subclasses at start
 * and swizzles them up front. This realizes every subclass to inspect it, so the cost grows with
 * the number of view controllers in the app - including ones it never uses - and it realizes
 * @c \@available -gated subclasses that reference newer-framework types, which crashes on OS
 * versions below the gate.
 *
 * With this option, only classes the app actually instantiates are touched: a class that can't
 * exist on the current OS is never instantiated, so it's never realized or swizzled. This cuts
 * start-up work and avoids the gated-subclass crash while producing the same @c ui.load
 * auto-instrumentation transactions.
 *
 * @warning This is an experimental feature and is therefore disabled by default.
 * @see https://github.com/getsentry/sentry-cocoa/issues/8548
 */
@property (nonatomic) BOOL enableUIViewControllerInitSwizzling;

/// Initializes experimental options with default values.
- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
