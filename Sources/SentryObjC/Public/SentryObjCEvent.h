#import "SentryObjCLevel.h"
#import <Foundation/Foundation.h>

@class SentryObjCBreadcrumb;
@class SentryObjCDebugMeta;
@class SentryObjCException;
@class SentryObjCId;
@class SentryObjCMessage;
@class SentryObjCRequest;
@class SentryObjCStacktrace;
@class SentryObjCThread;
@class SentryObjCUser;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCEvent : NSObject

@property (nonatomic, strong) SentryObjCId *eventId;
@property (nonatomic, strong, nullable) SentryObjCMessage *message;
@property (nonatomic, copy, nullable) NSError *error;
@property (nonatomic, strong, nullable) NSDate *timestamp;
@property (nonatomic, strong, nullable) NSDate *startTimestamp;
@property (nonatomic) SentryObjCLevel level;
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
@property (nonatomic, strong, nullable) SentryObjCUser *user;
@property (nonatomic, strong, nullable)
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *context;
@property (nonatomic, strong, nullable) NSArray<SentryObjCThread *> *threads;
@property (nonatomic, strong, nullable) NSArray<SentryObjCException *> *exceptions;
@property (nonatomic, strong, nullable) SentryObjCStacktrace *stacktrace;
@property (nonatomic, strong, nullable) NSArray<SentryObjCDebugMeta *> *debugMeta;
@property (nonatomic, strong, nullable) NSArray<SentryObjCBreadcrumb *> *breadcrumbs;
@property (nonatomic, strong, nullable) SentryObjCRequest *request;

- (instancetype)init;
- (instancetype)initWithLevel:(SentryObjCLevel)level;
- (instancetype)initWithError:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
