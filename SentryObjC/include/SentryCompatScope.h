#import <Foundation/Foundation.h>
#import "SentryCompatLevel.h"

@class SentryCompatSpan;
@class SentryCompatUser;
@class SentryCompatBreadcrumb;
@class SentryCompatAttachment;

NS_ASSUME_NONNULL_BEGIN

/// Contextual data attached to every captured event.
@interface SentryCompatScope : NSObject

- (instancetype)initWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs;
- (instancetype)init;
- (instancetype)initWithScope:(SentryCompatScope *)scope;

@property (nonatomic, strong, nullable) SentryCompatSpan *span;
@property (nonatomic, copy, nullable) NSString *replayId;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, NSString *> *tags;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *attributes;

- (void)setUser:(nullable SentryCompatUser *)user;
- (void)setTagValue:(NSString *)value forKey:(NSString *)key;
- (void)removeTagForKey:(NSString *)key;
- (void)setTags:(nullable NSDictionary<NSString *, NSString *> *)tags;
- (void)setExtras:(nullable NSDictionary<NSString *, id> *)extras;
- (void)setExtraValue:(nullable id)value forKey:(NSString *)key;
- (void)removeExtraForKey:(NSString *)key;
- (void)setDist:(nullable NSString *)dist;
- (void)setEnvironment:(nullable NSString *)environment;
- (void)setFingerprint:(nullable NSArray<NSString *> *)fingerprint;
- (void)setLevel:(SentryCompatLevel)level;
- (void)addBreadcrumb:(SentryCompatBreadcrumb *)crumb;
- (void)clearBreadcrumbs;
- (void)setContextValue:(NSDictionary<NSString *, id> *)value forKey:(NSString *)key;
- (void)removeContextForKey:(NSString *)key;
- (void)addAttachment:(SentryCompatAttachment *)attachment;
- (void)setAttributeValue:(id)value forKey:(NSString *)key;
- (void)removeAttributeForKey:(NSString *)key;
- (void)clearAttachments;
- (void)clear;

@end

NS_ASSUME_NONNULL_END
