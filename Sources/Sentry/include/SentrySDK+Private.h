#if __has_include(<Sentry/SentryOptions.h>)
#    import <Sentry/SentryProfilingConditionals.h>
#else
#    import "SentryProfilingConditionals.h"
#endif

#if __has_include(<Sentry/SentryOptions.h>)
#    import <Sentry/SentrySDK.h>
#else
#    import "SentrySDK.h"
#endif

@class SentryAppStartMeasurement;
@class SentryEnvelope;
@class SentryFeedback;
@class SentryHub;
@class SentryId;

NS_ASSUME_NONNULL_BEGIN

@interface SentrySDK ()

+ (void)captureCrashEvent:(SentryEvent *)event;

+ (void)captureCrashEvent:(SentryEvent *)event withScope:(SentryScope *)scope;

/**
 * SDK private field to store the state if onCrashedLastRun was called.
 */
@property (nonatomic, class) BOOL crashedLastRunCalled;

+ (void)setDetectedStartUpCrash:(BOOL)value;

+ (void)setAppStartMeasurement:(nullable SentryAppStartMeasurement *)appStartMeasurement;

+ (nullable SentryAppStartMeasurement *)getAppStartMeasurement;

@property (nonatomic, class) NSUInteger startInvocations;
@property (nullable, nonatomic, class) NSDate *startTimestamp;

+ (SentryHub *)currentHub;

/**
 * The option used to start the SDK
 */
@property (nonatomic, nullable, readonly, class) SentryOptions *options;

/**
 * Needed by hybrid SDKs as react-native to synchronously store an envelope to disk.
 */
+ (void)storeEnvelope:(SentryEnvelope *)envelope;

/**
 * Needed by hybrid SDKs as react-native to synchronously capture an envelope.
 */
+ (void)captureEnvelope:(SentryEnvelope *)envelope;
/**
 * Captures user feedback that was manually gathered and sends it to Sentry.
 * @param feedback The feedback to send to Sentry.
 * @note If you'd prefer not to have to build the UI required to gather the feedback from the user,
 * consider using `showUserFeedbackForm`, which delivers a prepackaged user feedback experience. See
 * @c SentryOptions.configureUserFeedback to customize a fully managed integration. See
 * https://docs.sentry.io/platforms/apple/user-feedback/ for more information.
 */
+ (void)captureFeedback:(SentryFeedback *)feedback NS_SWIFT_NAME(capture(feedback:));

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
/**
 * Display a form to gather information from an end user in the app to send to Sentry as a user
 * feedback event.
 * @see @c SentryOptions.configureUserFeedback to customize the experience, currently only on iOS.
 * @warning This is an experimental feature and may still have bugs.
 * @note This is a fully managed user feedback flow; there will be no need to call
 * @c SentrySDK.captureUserFeedback . See
 * https://docs.sentry.io/platforms/apple/user-feedback/ for more information.
 */
+ (void)showUserFeedbackForm;
#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT

@end

NS_ASSUME_NONNULL_END
