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
 * Enables network detail capture for Session Replay.
 *
 * When enabled, the SDK can capture request and response headers and bodies for network
 * requests during session replay. You must also configure
 * @c sessionReplay.networkDetailAllowUrls with URL patterns to specify which
 * requests should be captured.
 */
@property (nonatomic) BOOL enableReplayNetworkDetailsCapturing;

/// Initializes experimental options with default values.
- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
