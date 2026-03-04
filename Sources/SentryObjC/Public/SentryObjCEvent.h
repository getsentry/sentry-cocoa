#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"
#import "SentryObjCLevel.h"
#import "SentryObjCSerializable.h"

@class SentryBreadcrumb;
@class SentryDebugMeta;
@class SentryException;
@class SentryId;
@class SentryMessage;
@class SentryRequest;
@class SentryStacktrace;
@class SentryThread;
@class SentryUser;

NS_ASSUME_NONNULL_BEGIN

/**
 * Event payload sent to Sentry.
 *
 * @see SentrySDK
 * @see SentryClient
 */
@interface SentryEvent : NSObject <SentrySerializable>

@property (nonatomic, strong) SentryId *eventId;
@property (nonatomic, strong, nullable) SentryMessage *message;
@property (nonatomic, copy, nullable) NSError *error;
@property (nonatomic, strong, nullable) NSDate *timestamp;
@property (nonatomic, strong, nullable) NSDate *startTimestamp;
@property (nonatomic) SentryLevel level;
@property (nonatomic, copy) NSString *platform;
@property (nonatomic, copy, nullable) NSString *logger;
@property (nonatomic, copy, nullable) NSString *serverName;
@property (nonatomic, copy, nullable) NSString *releaseName;
@property (nonatomic, copy, nullable) NSString *dist;
@property (nonatomic, copy, nullable) NSString *environment;
@property (nonatomic, copy, nullable) NSString *transaction;
@property (nonatomic, copy, nullable) NSString *type;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSString *> *tags;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *extra;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *sdk;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSString *> *modules;
@property (nonatomic, strong, nullable) NSArray<NSString *> *fingerprint;
@property (nonatomic, strong, nullable) SentryUser *user;
@property (nonatomic, strong, nullable)
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *context;
@property (nonatomic, strong, nullable) NSArray<SentryThread *> *threads;
@property (nonatomic, strong, nullable) NSArray<SentryException *> *exceptions;
@property (nonatomic, strong, nullable) SentryStacktrace *stacktrace;
@property (nonatomic, strong, nullable) NSArray<SentryDebugMeta *> *debugMeta;
@property (nonatomic, strong, nullable) NSArray<SentryBreadcrumb *> *breadcrumbs;
@property (nonatomic, strong, nullable) SentryRequest *request;

- (instancetype)init;
- (instancetype)initWithLevel:(SentryLevel)level;
- (instancetype)initWithError:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
