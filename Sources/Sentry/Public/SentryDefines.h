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

#if __has_include(<UIKit/UIKit.h>)

#    import <UIKit/UIKit.h>

#    define SENTRY_UIDevice UIDevice
#    define SENTRY_UIButton UIButton
#    define SENTRY_UITextField UITextField
#    define SENTRY_UIViewController UIViewController
#    define SENTRY_UIView UIView
#    define SENTRY_UIBarButtonItem UIBarButtonItem
#    define SENTRY_UISegmentedControl UISegmentedControl
#    define SENTRY_UIPageControl UIPageControl
#    define SENTRY_UIApplication UIApplication
#    define SENTRY_UIWindow UIWindow

#    define SENTRY_UIApplicationDidBecomeActiveNotification UIApplicationDidBecomeActiveNotification
#    define SENTRY_UIApplicationWillResignActiveNotification                                       \
        UIApplicationWillResignActiveNotification
#    define SENTRY_UIApplicationWillTerminateNotification UIApplicationWillTerminateNotification
#    define SENTRY_UIKeyboardDidShowNotification UIKeyboardDidShowNotification
#    define SENTRY_UIKeyboardDidHideNotification UIKeyboardDidHideNotification
#    define SENTRY_UIApplicationUserDidTakeScreenshotNotification                                  \
        UIApplicationUserDidTakeScreenshotNotification
#    define SENTRY_UIDeviceBatteryLevelDidChangeNotification                                       \
        UIDeviceBatteryLevelDidChangeNotification
#    define SENTRY_UIDeviceBatteryStateDidChangeNotification                                       \
        UIDeviceBatteryStateDidChangeNotification
#    define SENTRY_UIDeviceOrientationDidChangeNotification UIDeviceOrientationDidChangeNotification
#    define SENTRY_UIDeviceOrientationDidChangeNotification UIDeviceOrientationDidChangeNotification
#    define SENTRY_UIApplicationDidEnterBackgroundNotification                                     \
        UIApplicationDidEnterBackgroundNotification
#    define SENTRY_UIApplicationDidReceiveMemoryWarningNotification                                \
        UIApplicationDidReceiveMemoryWarningNotification
#    define SENTRY_UIApplicationDidFinishLaunchingNotification                                     \
        UIApplicationDidFinishLaunchingNotification
#    define SENTRY_UIWindowDidBecomeVisibleNotification UIWindowDidBecomeVisibleNotification
#    define SENTRY_UISceneWillConnectNotification UISceneWillConnectNotification
#    define SENTRY_UIApplicationWillEnterForegroundNotification                                    \
        UIApplicationWillEnterForegroundNotification
#    define SENTRY_UIApplicationWillEnterForegroundNotification                                    \
        UIApplicationWillEnterForegroundNotification

#    if CONFIGURATION != Debug_Use_UIKit
#        undef SENTRY_UIDevice
#        undef SENTRY_UIButton
#        undef SENTRY_UITextField
#        undef SENTRY_UIViewController
#        undef SENTRY_UIView
#        undef SENTRY_UIBarButtonItem
#        undef SENTRY_UISegmentedControl
#        undef SENTRY_UIPageControl
#        undef SENTRY_UIApplication
#        undef SENTRY_UIWindow

#        undef SENTRY_UIApplicationDidBecomeActiveNotification
#        undef SENTRY_UIApplicationWillResignActiveNotification
#        undef SENTRY_UIApplicationWillTerminateNotification
#        undef SENTRY_UIKeyboardDidShowNotification
#        undef SENTRY_UIKeyboardDidHideNotification
#        undef SENTRY_UIApplicationUserDidTakeScreenshotNotification
#        undef SENTRY_UIDeviceBatteryLevelDidChangeNotification
#        undef SENTRY_UIDeviceBatteryStateDidChangeNotification
#        undef SENTRY_UIDeviceOrientationDidChangeNotification
#        undef SENTRY_UIDeviceOrientationDidChangeNotification
#        undef SENTRY_UIApplicationDidEnterBackgroundNotification
#        undef SENTRY_UIApplicationDidReceiveMemoryWarningNotification
#        undef SENTRY_UIApplicationDidFinishLaunchingNotification
#        undef SENTRY_UIWindowDidBecomeVisibleNotification
#        undef SENTRY_UISceneWillConnectNotification
#        undef SENTRY_UIApplicationWillEnterForegroundNotification
#        undef SENTRY_UIApplicationWillEnterForegroundNotification

#        define SENTRY_UIDevice NSClassFromString(@"UIDevice")
#        define SENTRY_UIButton NSClassFromString(@"UIButton")
#        define SENTRY_UITextField NSClassFromString(@"UITextField")
#        define SENTRY_UIViewController NSClassFromString(@"UIViewController")
#        define SENTRY_UIView NSClassFromString(@"UIView")
#        define SENTRY_UIBarButtonItem NSClassFromString(@"UIBarButtonItem")
#        define SENTRY_UISegmentedControl NSClassFromString(@"UISegmentedControl")
#        define SENTRY_UIPageControl NSClassFromString(@"UIPageControl")
#        define SENTRY_UIApplication NSClassFromString(@"UIApplication")
#        define SENTRY_UIWindow NSClassFromString(@"UIWindow")

#        define SENTRY_UIApplicationDidBecomeActiveNotification                                    \
            @"UIApplicationDidBecomeActiveNotification"
#        define SENTRY_UIApplicationWillResignActiveNotification                                   \
            @"UIApplicationWillResignActiveNotification"
#        define SENTRY_UIApplicationWillTerminateNotification                                      \
            @"UIApplicationWillTerminateNotification"
#        define SENTRY_UIKeyboardDidShowNotification @"UIKeyboardDidShowNotification"
#        define SENTRY_UIKeyboardDidHideNotification @"UIKeyboardDidHideNotification"
#        define SENTRY_UIApplicationUserDidTakeScreenshotNotification                              \
            @"UIApplicationUserDidTakeScreenshotNotification"
#        define SENTRY_UIDeviceBatteryLevelDidChangeNotification                                   \
            @"UIDeviceBatteryLevelDidChangeNotification"
#        define SENTRY_UIDeviceBatteryStateDidChangeNotification                                   \
            @"UIDeviceBatteryStateDidChangeNotification"
#        define SENTRY_UIDeviceOrientationDidChangeNotification                                    \
            @"UIDeviceOrientationDidChangeNotification"
#        define SENTRY_UIDeviceOrientationDidChangeNotification                                    \
            @"UIDeviceOrientationDidChangeNotification"
#        define SENTRY_UIApplicationDidEnterBackgroundNotification                                 \
            @"UIApplicationDidEnterBackgroundNotification"
#        define SENTRY_UIApplicationDidReceiveMemoryWarningNotification                            \
            @"UIApplicationDidReceiveMemoryWarningNotification"
#        define SENTRY_UIApplicationDidFinishLaunchingNotification                                 \
            @"UIApplicationDidFinishLaunchingNotification"
#        define SENTRY_UIWindowDidBecomeVisibleNotification @"UIWindowDidBecomeVisibleNotification"
#        define SENTRY_UISceneWillConnectNotification @"UISceneWillConnectNotification"
#        define SENTRY_UIApplicationWillEnterForegroundNotification                                \
            @"UIApplicationWillEnterForegroundNotification"
#        define SENTRY_UIApplicationWillEnterForegroundNotification                                \
            @"UIApplicationWillEnterForegroundNotification"
#    endif // !defined(SENTRY_USE_UIKIT)

#endif //  __has_include(<UIKit/UIKit.h>)

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
