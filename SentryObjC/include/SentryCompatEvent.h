#import <Foundation/Foundation.h>
#import "SentryCompatLevel.h"

@class SentryCompatId;
@class SentryCompatMessage;
@class SentryCompatUser;
@class SentryCompatThread;
@class SentryCompatException;
@class SentryCompatStacktrace;
@class SentryCompatDebugMeta;
@class SentryCompatBreadcrumb;
@class SentryCompatRequest;

NS_ASSUME_NONNULL_BEGIN

/// A Sentry event payload.
@interface SentryCompatEvent : NSObject

- (instancetype)init;
- (instancetype)initWithLevel:(SentryCompatLevel)level;
- (instancetype)initWithError:(NSError *)error;

@property (nonatomic, strong) SentryCompatId *eventId;
@property (nonatomic, strong, nullable) SentryCompatMessage *message;
@property (nonatomic, copy, nullable) NSError *error;
@property (nonatomic, copy, nullable) NSDate *timestamp;
@property (nonatomic, copy, nullable) NSDate *startTimestamp;
@property (nonatomic) SentryCompatLevel level;
@property (nonatomic, copy) NSString *platform;
@property (nonatomic, copy, nullable) NSString *logger;
@property (nonatomic, copy, nullable) NSString *serverName;
@property (nonatomic, copy, nullable) NSString *releaseName;
@property (nonatomic, copy, nullable) NSString *dist;
@property (nonatomic, copy, nullable) NSString *environment;
@property (nonatomic, copy, nullable) NSString *transaction;
@property (nonatomic, copy, nullable) NSString *type;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *tags;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *extra;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *sdk;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *modules;
@property (nonatomic, copy, nullable) NSArray<NSString *> *fingerprint;
@property (nonatomic, strong, nullable) SentryCompatUser *user;
@property (nonatomic, copy, nullable)
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *context;
@property (nonatomic, copy, nullable) NSArray<SentryCompatThread *> *threads;
@property (nonatomic, copy, nullable) NSArray<SentryCompatException *> *exceptions;
@property (nonatomic, strong, nullable) SentryCompatStacktrace *stacktrace;
@property (nonatomic, copy, nullable) NSArray<SentryCompatDebugMeta *> *debugMeta;
@property (nonatomic, copy, nullable) NSArray<SentryCompatBreadcrumb *> *breadcrumbs;
@property (nonatomic, strong, nullable) SentryCompatRequest *request;

@end

NS_ASSUME_NONNULL_END
