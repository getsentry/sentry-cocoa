#import "PrivatesHeader.h"
#import "SentryAppStartMeasurement.h"
#import "SentryEnvelope.h"
#import "SentryEnvelopeItemType.h"
#import "SentryScreenFrames.h"

@class SentryDebugMeta, SentryAppStartMeasurement, SentryScreenFrames, SentryOptions,
    SentryBreadcrumb, SentryUser;

NS_ASSUME_NONNULL_BEGIN

/**
 * A callback to be notified when the @c AppStartMeasurement is available.
 */
typedef void (^SentryOnAppStartMeasurementAvailable)(
    SentryAppStartMeasurement *_Nullable appStartMeasurement);

/**
 * @warning This class is reserved for hybrid SDKs. Methods may be changed, renamed or removed
 * without notice. If you want to use one of these methods here please open up an issue and let us
 * know.
 * @note The name of this class is supposed to be a bit weird and ugly. The name starts with private
 * on purpose so users don't see it in code completion when typing Sentry. We also add only at the
 * end to make it more obvious you shouldn't use it.
 */
@interface PrivateSentrySDKOnly : NSObject

/**
 * For storing an envelope synchronously to disk.
 */
+ (void)storeEnvelope:(SentryEnvelope *)envelope;

+ (void)captureEnvelope:(SentryEnvelope *)envelope;

/**
 * Create an envelope from @c NSData. Needed for example by Flutter.
 */
+ (nullable SentryEnvelope *)envelopeWithData:(NSData *)data;

/**
 * Returns the current list of debug images. Be aware that the @c SentryDebugMeta is actually
 * describing a debug image.
 * @todo This class should be renamed to @c SentryDebugImage in a future version.
 */
+ (NSArray<SentryDebugMeta *> *)getDebugImages;

/**
 * Override SDK information.
 */
+ (void)setSdkName:(NSString *)sdkName andVersionString:(NSString *)versionString;

/**
 * Override SDK information.
 */
+ (void)setSdkName:(NSString *)sdkName;

/**
 * Retrieves the SDK name
 */
+ (NSString *)getSdkName;

/**
 * Retrieves the SDK version string
 */
+ (NSString *)getSdkVersionString;

/**
 * Retrieves extra context
 */
+ (NSDictionary *)getExtraContext;

@property (class, nullable, nonatomic, copy)
    SentryOnAppStartMeasurementAvailable onAppStartMeasurementAvailable;

@property (class, nullable, nonatomic, readonly) SentryAppStartMeasurement *appStartMeasurement;

@property (class, nonatomic, readonly, copy) NSString *installationID;

@property (class, nonatomic, readonly, copy) SentryOptions *options;

/**
 * If enabled, the SDK won't send the app start measurement with the first transaction. Instead, if
 * @c enableAutoPerformanceTracing is enabled, the SDK measures the app start and then calls
 * @c onAppStartMeasurementAvailable. Furthermore, the SDK doesn't set all values for the app start
 * measurement because the HybridSDKs initialize the Cocoa SDK too late to receive all
 * notifications. Instead, the SDK sets the @c appStartDuration to @c 0 and the
 * @c didFinishLaunchingTimestamp to @c timeIntervalSinceReferenceDate.
 * @note Default is @c NO.
 */
@property (class, nonatomic, assign) BOOL appStartMeasurementHybridSDKMode;

#if SENTRY_HAS_UIKIT
/**
 * Allows hybrid SDKs to enable frame tracking measurements despite other options.
 */
@property (class, nonatomic, assign) BOOL framesTrackingMeasurementHybridSDKMode;

@property (class, nonatomic, assign, readonly) BOOL isFramesTrackingRunning;

@property (class, nonatomic, assign, readonly) SentryScreenFrames *currentScreenFrames;

+ (NSArray<NSData *> *)captureScreenshots;

+ (NSData *)captureViewHierarchy;
#endif

+ (SentryUser *)userWithDictionary:(NSDictionary *)dictionary;

+ (SentryBreadcrumb *)breadcrumbWithDictionary:(NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END
