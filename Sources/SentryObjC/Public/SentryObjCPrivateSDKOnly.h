#import <Foundation/Foundation.h>

@class SentryObjCEnvelope;
@class SentryObjCId;
@class SentryObjCSpanId;
@class SentryObjCUser;
@class SentryObjCBreadcrumb;

NS_ASSUME_NONNULL_BEGIN

/**
 * @warning This class is reserved for hybrid SDKs. Methods may be changed, renamed or removed
 * without notice. If you want to use one of these methods here please open up an issue and let us
 * know.
 * @note The name of this class is supposed to be a bit weird and ugly. The name starts with private
 * on purpose so users don't see it in code completion when typing Sentry. We also add only at the
 * end to make it more obvious you shouldn't use it.
 */
@interface SentryObjCPrivateSDKOnly : NSObject

/// For storing an envelope synchronously to disk.
+ (void)storeEnvelope:(SentryObjCEnvelope *)envelope;

/// Captures an envelope and sends it to Sentry.
+ (void)captureEnvelope:(SentryObjCEnvelope *)envelope;

/// Create an envelope from @c NSData. Needed for example by Flutter.
+ (nullable SentryObjCEnvelope *)envelopeWithData:(NSData *)data;

/// Override SDK information with the given name and version string.
+ (void)setSdkName:(NSString *)sdkName andVersionString:(NSString *)versionString;

/// Override SDK name.
+ (void)setSdkName:(NSString *)sdkName;

/// Retrieves the SDK name.
+ (NSString *)getSdkName;

/// Retrieves the SDK version string.
+ (NSString *)getSdkVersionString;

/// Add a package to the SDK packages.
+ (void)addSdkPackage:(NSString *)name version:(NSString *)version;

/// Retrieves extra context.
+ (NSDictionary *)getExtraContext;

/// Allows hybrid SDKs to thread-safe set the current trace.
+ (void)setTrace:(SentryObjCId *)traceId spanId:(SentryObjCSpanId *)spanId;

/// A unique installation ID for this device.
@property (class, nonatomic, readonly, copy) NSString *installationID;

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

/// Creates a @c SentryObjCUser from a dictionary.
+ (SentryObjCUser *)userWithDictionary:(NSDictionary *)dictionary;

/// Creates a @c SentryObjCBreadcrumb from a dictionary.
+ (SentryObjCBreadcrumb *)breadcrumbWithDictionary:(NSDictionary *)dictionary;

/**
 * Sets a custom log output handler. This allows hybrid SDKs (React Native, Flutter, etc.)
 * to intercept SDK log messages and forward them to their respective consoles.
 * @param output A block that receives the formatted log message string.
 */
+ (void)setLogOutput:(void (^)(NSString *))output;

/**
 * Tell the crash reporter to ignore the next occurrence of the given signal on the calling thread.
 * Used by hybrid SDKs to prevent duplicate crash reports when the host runtime is about to raise
 * a signal that has already been captured as a managed exception. The ignore is consumed by the
 * next signal delivery on that thread, regardless of whether it matches.
 * @param signum The signal number to ignore (e.g. SIGABRT).
 */
+ (void)ignoreNextSignal:(int)signum;

@end

NS_ASSUME_NONNULL_END
