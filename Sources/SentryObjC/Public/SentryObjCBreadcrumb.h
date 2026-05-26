#import "SentryObjCLevel.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCBreadcrumb : NSObject

@property (nonatomic) SentryObjCLevel level;
@property (nonatomic, copy) NSString *category;
@property (nonatomic, strong, nullable) NSDate *timestamp;
@property (nonatomic, copy, nullable) NSString *type;
@property (nonatomic, copy, nullable) NSString *message;
@property (nonatomic, copy, nullable) NSString *origin;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *data;

- (instancetype)initWithLevel:(SentryObjCLevel)level category:(NSString *)category;

@end

NS_ASSUME_NONNULL_END
