#import <Foundation/Foundation.h>

#ifdef __cplusplus
#    define SENTRY_EXTERN extern "C" __attribute__((visibility("default")))
#else
#    define SENTRY_EXTERN extern __attribute__((visibility("default")))
#endif

#if TARGET_OS_IOS || TARGET_OS_TV
#    define SENTRY_HAS_UIKIT 1
#else
#    define SENTRY_HAS_UIKIT 0
#endif

#if TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_MACCATALYST
#    define SENTRY_HAS_METRIC_KIT 1
#else
#    define SENTRY_HAS_METRIC_KIT 0
#endif

typedef NS_ENUM(NSInteger, SENTRY_UIDeviceBatteryState) {
    SENTRY_UIDeviceBatteryStateUnknown,
    SENTRY_UIDeviceBatteryStateUnplugged, // on battery, discharging
    SENTRY_UIDeviceBatteryStateCharging, // plugged in, less than 100%
    SENTRY_UIDeviceBatteryStateFull, // plugged in, at 100%
} API_UNAVAILABLE(tvos); // available in iPhone 3.0

typedef NS_ENUM(NSInteger, SENTRY_UIDeviceOrientation) {
    SENTRY_UIDeviceOrientationUnknown,
    SENTRY_UIDeviceOrientationPortrait, // Device oriented vertically, home button on the bottom
    SENTRY_UIDeviceOrientationPortraitUpsideDown, // Device oriented vertically, home button on the
                                                  // top
    SENTRY_UIDeviceOrientationLandscapeLeft, // Device oriented horizontally, home button on the
                                             // right
    SENTRY_UIDeviceOrientationLandscapeRight, // Device oriented horizontally, home button on the
                                              // left
    SENTRY_UIDeviceOrientationFaceUp, // Device oriented flat, face up
    SENTRY_UIDeviceOrientationFaceDown // Device oriented flat, face down
} API_UNAVAILABLE(tvos);

static inline BOOL
SENTRY_UIDeviceOrientationIsLandscape(SENTRY_UIDeviceOrientation orientation) API_UNAVAILABLE(tvos)
{
    return ((orientation) == SENTRY_UIDeviceOrientationLandscapeLeft
        || (orientation) == SENTRY_UIDeviceOrientationLandscapeRight);
}

static inline BOOL
SENTRY_UIDeviceOrientationIsPortrait(SENTRY_UIDeviceOrientation orientation) API_UNAVAILABLE(tvos)
{
    return ((orientation) == SENTRY_UIDeviceOrientationPortrait
        || (orientation) == SENTRY_UIDeviceOrientationPortraitUpsideDown);
}

static inline __attribute__((always_inline)) BOOL
SENTRY_UIDeviceOrientationIsValidInterfaceOrientation(SENTRY_UIDeviceOrientation orientation)
    API_UNAVAILABLE(tvos)
{
    return ((orientation) == SENTRY_UIDeviceOrientationPortrait
        || (orientation) == SENTRY_UIDeviceOrientationPortraitUpsideDown
        || (orientation) == SENTRY_UIDeviceOrientationLandscapeLeft
        || (orientation) == SENTRY_UIDeviceOrientationLandscapeRight);
}

typedef NS_ENUM(NSInteger, SENTRY_UITouchPhase) {
    SENTRY_UITouchPhaseBegan, // whenever a finger touches the surface.
    SENTRY_UITouchPhaseMoved, // whenever a finger moves on the surface.
    SENTRY_UITouchPhaseStationary, // whenever a finger is touching the surface but hasn't moved
                                   // since the previous event.
    SENTRY_UITouchPhaseEnded, // whenever a finger leaves the surface.
    SENTRY_UITouchPhaseCancelled, // whenever a touch doesn't end but we need to stop tracking (e.g.
                                  // putting device to face)
    SENTRY_UITouchPhaseRegionEntered API_AVAILABLE(ios(13.4), tvos(13.4))
        API_UNAVAILABLE(watchos), // whenever a touch is entering the region of a user interface
    SENTRY_UITouchPhaseRegionMoved API_AVAILABLE(ios(13.4), tvos(13.4))
        API_UNAVAILABLE(watchos), // when a touch is inside the region of a user interface, but
                                  // hasn’t yet made contact or left the region
    SENTRY_UITouchPhaseRegionExited API_AVAILABLE(ios(13.4), tvos(13.4))
        API_UNAVAILABLE(watchos), // when a touch is exiting the region of a user interface
};

typedef NS_OPTIONS(NSUInteger, SENTRY_UIControlEvents) {
    SENTRY_UIControlEventTouchDown = 1 << 0, // on all touch downs
    SENTRY_UIControlEventTouchDownRepeat = 1 << 1, // on multiple touchdowns (tap count > 1)
    SENTRY_UIControlEventTouchDragInside = 1 << 2,
    SENTRY_UIControlEventTouchDragOutside = 1 << 3,
    SENTRY_UIControlEventTouchDragEnter = 1 << 4,
    SENTRY_UIControlEventTouchDragExit = 1 << 5,
    SENTRY_UIControlEventTouchUpInside = 1 << 6,
    SENTRY_UIControlEventTouchUpOutside = 1 << 7,
    SENTRY_UIControlEventTouchCancel = 1 << 8,

    SENTRY_UIControlEventValueChanged = 1 << 12, // sliders, etc.
    SENTRY_UIControlEventPrimaryActionTriggered API_AVAILABLE(ios(9.0)) = 1
        << 13, // semantic action: for buttons, etc.
    SENTRY_UIControlEventMenuActionTriggered API_AVAILABLE(ios(14.0)) = 1
        << 14, // triggered when the menu gesture fires but before the menu presents

    SENTRY_UIControlEventEditingDidBegin = 1 << 16, // UITextField
    SENTRY_UIControlEventEditingChanged = 1 << 17,
    SENTRY_UIControlEventEditingDidEnd = 1 << 18,
    SENTRY_UIControlEventEditingDidEndOnExit = 1 << 19, // 'return key' ending editing

    SENTRY_UIControlEventAllTouchEvents = 0x00000FFF, // for touch events
    SENTRY_UIControlEventAllEditingEvents = 0x000F0000, // for UITextField
    SENTRY_UIControlEventApplicationReserved = 0x0F000000, // range available for application use
    SENTRY_UIControlEventSystemReserved = 0xF0000000, // range reserved for internal framework use
    SENTRY_UIControlEventAllEvents = 0xFFFFFFFF
};

typedef NS_ENUM(NSInteger, SENTRY_UISceneActivationState) {
    SENTRY_UISceneActivationStateUnattached = -1,
    SENTRY_UISceneActivationStateForegroundActive,
    SENTRY_UISceneActivationStateForegroundInactive,
    SENTRY_UISceneActivationStateBackground
} API_AVAILABLE(ios(13.0));

#define SENTRY_UIDevice NSClassFromString(@"UIDevice")
#define SENTRY_UIButton NSClassFromString(@"UIButton")
#define SENTRY_UITextField NSClassFromString(@"UITextField")
#define SENTRY_UIViewController NSClassFromString(@"UIViewController")
#define SENTRY_UIView NSClassFromString(@"UIView")
#define SENTRY_UIBarButtonItem NSClassFromString(@"UIBarButtonItem")
#define SENTRY_UISegmentedControl NSClassFromString(@"UISegmentedControl")
#define SENTRY_UIPageControl NSClassFromString(@"UIPageControl")
#define SENTRY_UIApplication NSClassFromString(@"UIApplication")
#define SENTRY_UIWindow NSClassFromString(@"UIWindow")

#define SENTRY_UIApplicationDidBecomeActiveNotification @"UIApplicationDidBecomeActiveNotification"
#define SENTRY_UIApplicationWillResignActiveNotification                                           \
    @"UIApplicationWillResignActiveNotification"
#define SENTRY_UIApplicationWillTerminateNotification @"UIApplicationWillTerminateNotification"
#define SENTRY_UIKeyboardDidShowNotification @"UIKeyboardDidShowNotification"
#define SENTRY_UIKeyboardDidHideNotification @"UIKeyboardDidHideNotification"
#define SENTRY_UIApplicationUserDidTakeScreenshotNotification                                      \
    @"UIApplicationUserDidTakeScreenshotNotification"
#define SENTRY_UIDeviceBatteryLevelDidChangeNotification                                           \
    @"UIDeviceBatteryLevelDidChangeNotification"
#define SENTRY_UIDeviceBatteryStateDidChangeNotification                                           \
    @"UIDeviceBatteryStateDidChangeNotification"
#define SENTRY_UIDeviceOrientationDidChangeNotification @"UIDeviceOrientationDidChangeNotification"
#define SENTRY_UIDeviceOrientationDidChangeNotification @"UIDeviceOrientationDidChangeNotification"
#define SENTRY_UIApplicationDidEnterBackgroundNotification                                         \
    @"UIApplicationDidEnterBackgroundNotification"
#define SENTRY_UIApplicationDidReceiveMemoryWarningNotification                                    \
    @"UIApplicationDidReceiveMemoryWarningNotification"
#define SENTRY_UIApplicationDidFinishLaunchingNotification                                         \
    @"UIApplicationDidFinishLaunchingNotification"
#define SENTRY_UIWindowDidBecomeVisibleNotification @"UIWindowDidBecomeVisibleNotification"
#define SENTRY_UISceneWillConnectNotification @"UISceneWillConnectNotification"
#define SENTRY_UIApplicationWillEnterForegroundNotification                                        \
    @"UIApplicationWillEnterForegroundNotification"
#define SENTRY_UIApplicationWillEnterForegroundNotification                                        \
    @"UIApplicationWillEnterForegroundNotification"

#define SENTRY_NO_INIT                                                                             \
    -(instancetype)init NS_UNAVAILABLE;                                                            \
    +(instancetype) new NS_UNAVAILABLE;

@class SentryEvent, SentryBreadcrumb, SentrySamplingContext;
@protocol SentrySpan;

/**
 * Block used for returning after a request finished
 */
typedef void (^SentryRequestFinished)(NSError *_Nullable error);

/**
 * Block used for request operation finished, @c shouldDiscardEvent is @c YES if event
 * should be deleted regardless if an error occurred or not
 */
typedef void (^SentryRequestOperationFinished)(
    NSHTTPURLResponse *_Nullable response, NSError *_Nullable error);
/**
 * Block can be used to mutate a breadcrumb before it's added to the scope.
 * To avoid adding the breadcrumb altogether, return @c nil instead.
 */
typedef SentryBreadcrumb *_Nullable (^SentryBeforeBreadcrumbCallback)(
    SentryBreadcrumb *_Nonnull breadcrumb);

/**
 * Block can be used to mutate event before its send.
 * To avoid sending the event altogether, return nil instead.
 */
typedef SentryEvent *_Nullable (^SentryBeforeSendEventCallback)(SentryEvent *_Nonnull event);

/**
 * A callback to be notified when the last program execution terminated with a crash.
 */
typedef void (^SentryOnCrashedLastRunCallback)(SentryEvent *_Nonnull event);

/**
 * Block can be used to determine if an event should be queued and stored
 * locally. It will be tried to send again after next successful send. Note that
 * this will only be called once the event is created and send manually. Once it
 * has been queued once it will be discarded if it fails again.
 */
typedef BOOL (^SentryShouldQueueEvent)(
    NSHTTPURLResponse *_Nullable response, NSError *_Nullable error);

/**
 * Function pointer for a sampler callback.
 * @param samplingContext context of the sampling.
 * @return A sample rate that is >=  @c 0.0 and \<= @c 1.0 or @c nil if no sampling decision has
 * been taken. When returning a value out of range the SDK uses the default of @c 0.
 */
typedef NSNumber *_Nullable (^SentryTracesSamplerCallback)(
    SentrySamplingContext *_Nonnull samplingContext);

/**
 * Function pointer for span manipulation.
 * @param span The span to be used.
 */
typedef void (^SentrySpanCallback)(id<SentrySpan> _Nullable span);

/**
 * Log level.
 */
typedef NS_ENUM(NSInteger, SentryLogLevel) {
    kSentryLogLevelNone = 1,
    kSentryLogLevelError,
    kSentryLogLevelDebug,
    kSentryLogLevelVerbose
};

/**
 * Sentry level.
 */
typedef NS_ENUM(NSUInteger, SentryLevel) {
    // Defaults to None which doesn't get serialized
    kSentryLevelNone = 0,
    // Goes from Debug to Fatal so possible to: (level > Info) { .. }
    kSentryLevelDebug = 1,
    kSentryLevelInfo = 2,
    kSentryLevelWarning = 3,
    kSentryLevelError = 4,
    kSentryLevelFatal = 5
};

/**
 * Static internal helper to convert enum to string.
 */
static DEPRECATED_MSG_ATTRIBUTE(
    "Use nameForSentryLevel() instead.") NSString *_Nonnull const SentryLevelNames[]
    = {
          @"none",
          @"debug",
          @"info",
          @"warning",
          @"error",
          @"fatal",
      };

static NSUInteger const defaultMaxBreadcrumbs = 100;

/**
 * Transaction name source.
 */
typedef NS_ENUM(NSInteger, SentryTransactionNameSource) {
    kSentryTransactionNameSourceCustom = 0,
    kSentryTransactionNameSourceUrl,
    kSentryTransactionNameSourceRoute,
    kSentryTransactionNameSourceView,
    kSentryTransactionNameSourceComponent,
    kSentryTransactionNameSourceTask
};
