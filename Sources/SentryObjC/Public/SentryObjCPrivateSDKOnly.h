#import <Foundation/Foundation.h>

@class SentryObjCEnvelope;
@class SentryObjCId;
@class SentryObjCSpanId;
@class SentryObjCUser;
@class SentryObjCBreadcrumb;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCPrivateSDKOnly : NSObject

+ (void)storeEnvelope:(SentryObjCEnvelope *)envelope;
+ (void)captureEnvelope:(SentryObjCEnvelope *)envelope;
+ (nullable SentryObjCEnvelope *)envelopeWithData:(NSData *)data;

+ (void)setSdkName:(NSString *)sdkName andVersionString:(NSString *)versionString;
+ (void)setSdkName:(NSString *)sdkName;
+ (NSString *)getSdkName;
+ (NSString *)getSdkVersionString;
+ (void)addSdkPackage:(NSString *)name version:(NSString *)version;
+ (NSDictionary *)getExtraContext;

+ (void)setTrace:(SentryObjCId *)traceId spanId:(SentryObjCSpanId *)spanId;

@property (class, nonatomic, readonly, copy) NSString *installationID;
@property (class, nonatomic, assign) BOOL appStartMeasurementHybridSDKMode;

+ (SentryObjCUser *)userWithDictionary:(NSDictionary *)dictionary;
+ (SentryObjCBreadcrumb *)breadcrumbWithDictionary:(NSDictionary *)dictionary;

+ (void)setLogOutput:(void (^)(NSString *))output;
+ (void)ignoreNextSignal:(int)signum;

@end

NS_ASSUME_NONNULL_END
