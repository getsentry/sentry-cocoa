#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Options for experimental features that are subject to change or may be removed in future
 * versions.
 */
@interface SentryExperimentalOptions : NSObject

/**
 * A more reliable way to report unhandled C++ exceptions.
 *
 * Hooks into all instances of @c __cxa_throw to provide more comprehensive exception handling
 * across the app's runtime, regardless of how C++ modules are linked. Helps produce accurate
 * stack traces.
 *
 * @note Hooking @c __cxa_throw may cause issues with symbolication on iOS due to caching of
 * symbol references.
 *
 * @note Disabled by default.
 */
@property (nonatomic, assign) BOOL enableUnhandledCPPExceptionsV2;

/**
 * Forces enabling of session replay in environments the SDK would otherwise disable it in.
 *
 * Session replay is disabled by default on iOS 26+ unless the environment is detected as
 * reliable for masking text and images (e.g., @c UIDesignRequiresCompatibility is set, or the
 * app was built with Xcode < 26). Set this to @c YES to re-enable replay on iOS 26+ with the
 * understanding that masking cannot be fully guaranteed.
 *
 * @note Disabled by default.
 * @see https://github.com/getsentry/sentry-cocoa/issues/6389
 */
@property (nonatomic, assign) BOOL enableSessionReplayInUnreliableEnvironment;

/**
 * When enabled, the SDK uses a more efficient mechanism for detecting watchdog terminations.
 *
 * @note Disabled by default.
 */
@property (nonatomic, assign) BOOL enableWatchdogTerminationsV2;

@end

NS_ASSUME_NONNULL_END
