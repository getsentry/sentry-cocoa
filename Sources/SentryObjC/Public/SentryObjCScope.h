#import "SentryObjCLevel.h"
#import <Foundation/Foundation.h>

@class SentryObjCAttachment;
@class SentryObjCBreadcrumb;
@class SentryObjCUser;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCScope : NSObject

@property (nonatomic, copy, nullable) NSString *replayId;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, NSString *> *tags;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *attributes;

- (instancetype)init;
- (instancetype)initWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs;

- (void)setUser:(nullable SentryObjCUser *)user;
- (void)setTagValue:(NSString *)value forKey:(NSString *)key;
- (void)removeTagForKey:(NSString *)key;
- (void)setTags:(nullable NSDictionary<NSString *, NSString *> *)tags;
- (void)setExtras:(nullable NSDictionary<NSString *, id> *)extras;
- (void)setExtraValue:(nullable id)value forKey:(NSString *)key;
- (void)removeExtraForKey:(NSString *)key;
- (void)setDist:(nullable NSString *)dist;
- (void)setEnvironment:(nullable NSString *)environment;
- (void)setFingerprint:(nullable NSArray<NSString *> *)fingerprint;
- (void)setLevel:(SentryObjCLevel)level;
- (void)addBreadcrumb:(SentryObjCBreadcrumb *)crumb;
- (void)clearBreadcrumbs;
- (void)setContextValue:(NSDictionary<NSString *, id> *)value forKey:(NSString *)key;
- (void)removeContextForKey:(NSString *)key;
- (void)addAttachment:(SentryObjCAttachment *)attachment;
- (void)setAttributeValue:(id)value forKey:(NSString *)key;
- (void)removeAttributeForKey:(NSString *)key;
- (void)clearAttachments;
- (void)clear;

@end

NS_ASSUME_NONNULL_END
