#import <Foundation/Foundation.h>
#import "SOCSentryLevel.h"

@class SOCSentryId;
@class SOCSentryMessage;
@class SOCSentryUser;
@class SOCSentryThread;
@class SOCSentryException;
@class SOCSentryStacktrace;
@class SOCSentryDebugMeta;
@class SOCSentryBreadcrumb;
@class SOCSentryRequest;

NS_ASSUME_NONNULL_BEGIN

/// A Sentry event payload.
@interface SOCSentryEvent : NSObject

- (instancetype)init;
- (instancetype)initWithLevel:(SOCSentryLevel)level;
- (instancetype)initWithError:(NSError *)error;

@property (nonatomic, strong) SOCSentryId *eventId;
@property (nonatomic, strong, nullable) SOCSentryMessage *message;
@property (nonatomic, copy, nullable) NSError *error;
@property (nonatomic, copy, nullable) NSDate *timestamp;
@property (nonatomic, copy, nullable) NSDate *startTimestamp;
@property (nonatomic) SOCSentryLevel level;
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
@property (nonatomic, strong, nullable) SOCSentryUser *user;
@property (nonatomic, copy, nullable)
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *context;
@property (nonatomic, copy, nullable) NSArray<SOCSentryThread *> *threads;
@property (nonatomic, copy, nullable) NSArray<SOCSentryException *> *exceptions;
@property (nonatomic, strong, nullable) SOCSentryStacktrace *stacktrace;
@property (nonatomic, copy, nullable) NSArray<SOCSentryDebugMeta *> *debugMeta;
@property (nonatomic, copy, nullable) NSArray<SOCSentryBreadcrumb *> *breadcrumbs;
@property (nonatomic, strong, nullable) SOCSentryRequest *request;

@end

NS_ASSUME_NONNULL_END
