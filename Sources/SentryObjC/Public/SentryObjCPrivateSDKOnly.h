#import <Foundation/Foundation.h>

@class SentryObjCEnvelope;
@class SentryObjCId;
@class SentryObjCSpanId;
@class SentryObjCUser;
@class SentryObjCBreadcrumb;

NS_ASSUME_NONNULL_BEGIN

/**
 * @deprecated Use @c SentryObjCSDK.internal instead.
 * @warning This class is reserved for hybrid SDKs. Methods may be changed, renamed or removed
 * without notice. If you want to use one of these methods here please open up an issue and let us
 * know.
 * @note The name of this class is supposed to be a bit weird and ugly. The name starts with private
 * on purpose so users don't see it in code completion when typing Sentry. We also add only at the
 * end to make it more obvious you shouldn't use it.
 */
DEPRECATED_MSG_ATTRIBUTE("Use SentryObjCSDK.internal instead")
@interface SentryObjCPrivateSDKOnly : NSObject

/// @deprecated Use @c SentryObjCSDK.internal.envelope.store: instead.
+ (void)storeEnvelope:(SentryObjCEnvelope *)envelope
    DEPRECATED_MSG_ATTRIBUTE("Use SentryObjCSDK.internal.envelope.store: instead");

/// @deprecated Use @c SentryObjCSDK.internal.envelope.capture: instead.
+ (void)captureEnvelope:(SentryObjCEnvelope *)envelope
    DEPRECATED_MSG_ATTRIBUTE("Use SentryObjCSDK.internal.envelope.capture: instead");

/// @deprecated Use @c SentryObjCSDK.internal.envelope.deserializeFrom: instead.
+ (nullable SentryObjCEnvelope *)envelopeWithData:(NSData *)data
    DEPRECATED_MSG_ATTRIBUTE("Use SentryObjCSDK.internal.envelope.deserializeFrom: instead");

/// @deprecated Use @c SentryObjCSDK.internal.sdk.setName:version: instead.
+ (void)setSdkName:(NSString *)sdkName
    andVersionString:(NSString *)versionString
    DEPRECATED_MSG_ATTRIBUTE("Use SentryObjCSDK.internal.sdk.setName:version: instead");

/// @deprecated Use @c SentryObjCSDK.internal.sdk.name instead.
+ (void)setSdkName:(NSString *)sdkName
    DEPRECATED_MSG_ATTRIBUTE("Use SentryObjCSDK.internal.sdk.name instead");

/// @deprecated Use @c SentryObjCSDK.internal.sdk.name instead.
+ (NSString *)getSdkName DEPRECATED_MSG_ATTRIBUTE("Use SentryObjCSDK.internal.sdk.name instead");

/// @deprecated Use @c SentryObjCSDK.internal.sdk.versionString instead.
+ (NSString *)getSdkVersionString DEPRECATED_MSG_ATTRIBUTE(
    "Use SentryObjCSDK.internal.sdk.versionString instead");

/// @deprecated Use @c SentryObjCSDK.internal.sdk.addPackageName:version: instead.
+ (void)addSdkPackage:(NSString *)name
              version:(NSString *)version
    DEPRECATED_MSG_ATTRIBUTE("Use SentryObjCSDK.internal.sdk.addPackageName:version: instead");

/// @deprecated Use @c SentryObjCSDK.internal.sdk.extraContext instead.
+ (NSDictionary *)getExtraContext DEPRECATED_MSG_ATTRIBUTE(
    "Use SentryObjCSDK.internal.sdk.extraContext instead");

/// @deprecated Use @c SentryObjCSDK.internal.setTrace:spanId: instead.
+ (void)setTrace:(SentryObjCId *)traceId
          spanId:(SentryObjCSpanId *)spanId
    DEPRECATED_MSG_ATTRIBUTE("Use SentryObjCSDK.internal.setTrace:spanId: instead");

/// @deprecated Use @c SentryObjCSDK.internal.sdk.installationID instead.
@property (class, nonatomic, readonly, copy) NSString *installationID DEPRECATED_MSG_ATTRIBUTE(
    "Use SentryObjCSDK.internal.sdk.installationID instead");

/// @deprecated Use @c SentryObjCSDK.internal.appStart.hybridSDKMode instead.
@property (class, nonatomic, assign) BOOL appStartMeasurementHybridSDKMode DEPRECATED_MSG_ATTRIBUTE(
    "Use SentryObjCSDK.internal.appStart.hybridSDKMode instead");

/// @deprecated Use @c SentryObjCSDK.internal.user.fromDictionary: instead.
+ (SentryObjCUser *)userWithDictionary:(NSDictionary *)dictionary
    DEPRECATED_MSG_ATTRIBUTE("Use SentryObjCSDK.internal.user.fromDictionary: instead");

/// @deprecated Use @c SentryObjCSDK.internal.breadcrumbs.fromDictionary: instead.
+ (SentryObjCBreadcrumb *)breadcrumbWithDictionary:(NSDictionary *)dictionary
    DEPRECATED_MSG_ATTRIBUTE("Use SentryObjCSDK.internal.breadcrumbs.fromDictionary: instead");

/// @deprecated Use @c SentryObjCSDK.internal.setLogOutput: instead.
+ (void)setLogOutput:(void (^)(NSString *))output
    DEPRECATED_MSG_ATTRIBUTE("Use SentryObjCSDK.internal.setLogOutput: instead");

/// @deprecated Use @c SentryObjCSDK.internal.ignoreNextSignal: instead.
+ (void)ignoreNextSignal:(int)signum
    DEPRECATED_MSG_ATTRIBUTE("Use SentryObjCSDK.internal.ignoreNextSignal: instead");

@end

NS_ASSUME_NONNULL_END
