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
 * Enables network detail capture for Session Replay.
 *
 * When enabled, the SDK can capture request and response headers and bodies for network
 * requests during session replay. You must also configure
 * @c sessionReplay.networkDetailAllowUrls with URL patterns to specify which
 * requests should be captured.
 *
 * @note Disabled by default.
 */
@property (nonatomic, assign) BOOL enableReplayNetworkDetailsCapturing;

/**
 * When enabled, the SDK uses a more efficient mechanism for detecting watchdog terminations.
 *
 * @note Disabled by default.
 */
@property (nonatomic, assign) BOOL enableWatchdogTerminationsV2;

@end

NS_ASSUME_NONNULL_END
