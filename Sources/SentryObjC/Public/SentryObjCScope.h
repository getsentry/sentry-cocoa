#import <Foundation/Foundation.h>

#import "SentryObjCLevel.h"
#import "SentryObjCSerializable.h"
#import "SentryObjCSpanProtocol.h"

@class SentryAttachment;
@class SentryBreadcrumb;
@class SentryUser;

NS_ASSUME_NONNULL_BEGIN

/**
 * Scope holds contextual data sent with every event (tags, breadcrumbs, user, etc.).
 *
 * @see https://docs.sentry.io/platforms/apple/enriching-events/scopes/#whats-a-scope-whats-a-hub
 */
@interface SentryScope : NSObject <SentrySerializable>

/** Current span or transaction. */
@property (nullable, nonatomic, strong) id<SentrySpan> span;

/** Id of current session replay. */
@property (nullable, nonatomic, strong) NSString *replayId;

/** Currently set tags. */
@property (nonatomic, readonly, copy) NSDictionary<NSString *, NSString *> *tags;

/** Currently set attributes. */
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *attributes;

- (instancetype)initWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs;
- (instancetype)init;
- (instancetype)initWithScope:(SentryScope *)scope;

- (void)setUser:(SentryUser *)user;
- (void)setTagValue:(NSString *)value forKey:(NSString *)key;
- (void)removeTagForKey:(NSString *)key;
- (void)setTags:(NSDictionary<NSString *, NSString *> *)tags;
- (void)setExtras:(NSDictionary<NSString *, id> *)extras;
- (void)setExtraValue:(id)value forKey:(NSString *)key;
- (void)removeExtraForKey:(NSString *)key;
- (void)setDist:(NSString *)dist;
- (void)setEnvironment:(NSString *)environment;
- (void)setFingerprint:(NSArray<NSString *> *)fingerprint;
- (void)setLevel:(SentryLevel)level;
- (void)addBreadcrumb:(SentryBreadcrumb *)crumb;
- (void)clearBreadcrumbs;
- (NSDictionary<NSString *, id> *)serialize;
- (void)setContextValue:(NSDictionary<NSString *, id> *)value forKey:(NSString *)key;
- (void)removeContextForKey:(NSString *)key;
- (void)addAttachment:(SentryAttachment *)attachment;
- (void)setAttributeValue:(id)value forKey:(NSString *)key;
- (void)removeAttributeForKey:(NSString *)key;
- (void)clearAttachments;
- (void)clear;

@end

NS_ASSUME_NONNULL_END
