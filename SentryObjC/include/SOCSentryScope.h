#import <Foundation/Foundation.h>
#import "SOCSentryLevel.h"

@class SOCSentrySpan;
@class SOCSentryUser;
@class SOCSentryBreadcrumb;
@class SOCSentryAttachment;

NS_ASSUME_NONNULL_BEGIN

/// Contextual data attached to every captured event.
@interface SOCSentryScope : NSObject

- (instancetype)initWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs;
- (instancetype)init;
- (instancetype)initWithScope:(SOCSentryScope *)scope;

@property (nonatomic, strong, nullable) SOCSentrySpan *span;
@property (nonatomic, copy, nullable) NSString *replayId;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, NSString *> *tags;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *attributes;

- (void)setUser:(nullable SOCSentryUser *)user;
- (void)setTagValue:(NSString *)value forKey:(NSString *)key;
- (void)removeTagForKey:(NSString *)key;
- (void)setTags:(nullable NSDictionary<NSString *, NSString *> *)tags;
- (void)setExtras:(nullable NSDictionary<NSString *, id> *)extras;
- (void)setExtraValue:(nullable id)value forKey:(NSString *)key;
- (void)removeExtraForKey:(NSString *)key;
- (void)setDist:(nullable NSString *)dist;
- (void)setEnvironment:(nullable NSString *)environment;
- (void)setFingerprint:(nullable NSArray<NSString *> *)fingerprint;
- (void)setLevel:(SOCSentryLevel)level;
- (void)addBreadcrumb:(SOCSentryBreadcrumb *)crumb;
- (void)clearBreadcrumbs;
- (void)setContextValue:(NSDictionary<NSString *, id> *)value forKey:(NSString *)key;
- (void)removeContextForKey:(NSString *)key;
- (void)addAttachment:(SOCSentryAttachment *)attachment;
- (void)setAttributeValue:(id)value forKey:(NSString *)key;
- (void)removeAttributeForKey:(NSString *)key;
- (void)clearAttachments;
- (void)clear;

@end

NS_ASSUME_NONNULL_END
