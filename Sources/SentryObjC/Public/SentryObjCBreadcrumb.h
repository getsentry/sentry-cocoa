#import <Foundation/Foundation.h>

#import "SentryObjCLevel.h"
#import "SentryObjCSerializable.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Breadcrumb representing a discrete event that occurred before a Sentry event.
 *
 * @see SentryScope
 */
@interface SentryBreadcrumb : NSObject <SentrySerializable>

@property (nonatomic) SentryLevel level;
@property (nonatomic, copy) NSString *category;
@property (nonatomic, strong, nullable) NSDate *timestamp;
@property (nonatomic, copy, nullable) NSString *type;
@property (nonatomic, copy, nullable) NSString *message;
@property (nonatomic, copy, nullable) NSString *origin;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *data;

- (instancetype)initWithLevel:(SentryLevel)level category:(NSString *)category;
- (instancetype)init;
- (NSDictionary<NSString *, id> *)serialize;
- (BOOL)isEqual:(id)other;
- (BOOL)isEqualToBreadcrumb:(SentryBreadcrumb *)breadcrumb;
- (NSUInteger)hash;

@end

NS_ASSUME_NONNULL_END
