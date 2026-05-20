#import <Foundation/Foundation.h>
#import "SentryCompatLevel.h"

NS_ASSUME_NONNULL_BEGIN

/// A breadcrumb attached to a Sentry event.
@interface SentryCompatBreadcrumb : NSObject

- (instancetype)init;
- (instancetype)initWithLevel:(SentryCompatLevel)level category:(NSString *)category;

@property (nonatomic) SentryCompatLevel level;
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
