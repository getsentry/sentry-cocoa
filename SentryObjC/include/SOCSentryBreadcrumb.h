#import <Foundation/Foundation.h>
#import "SOCSentryLevel.h"

NS_ASSUME_NONNULL_BEGIN

/// A breadcrumb attached to a Sentry event.
@interface SOCSentryBreadcrumb : NSObject

- (instancetype)init;
- (instancetype)initWithLevel:(SOCSentryLevel)level category:(NSString *)category;

@property (nonatomic) SOCSentryLevel level;
@property (nonatomic, copy) NSString *category;
@property (nonatomic, copy, nullable) NSDate *timestamp;
@property (nonatomic, copy, nullable) NSString *type;
@property (nonatomic, copy, nullable) NSString *message;
@property (nonatomic, copy, nullable) NSString *origin;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *data;

- (BOOL)isEqual:(nullable id)object;
@property (nonatomic, readonly) NSUInteger hash;

@end

NS_ASSUME_NONNULL_END
