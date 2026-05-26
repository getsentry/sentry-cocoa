#import <Foundation/Foundation.h>

@class SentryObjCMechanismContext;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCMechanism : NSObject

@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy, nullable) NSString *desc;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *data;
@property (nonatomic, copy, nullable) NSNumber *handled;
@property (nonatomic, copy, nullable) NSNumber *synthetic;
@property (nonatomic, copy, nullable) NSString *helpLink;
@property (nonatomic, strong, nullable) SentryObjCMechanismContext *meta;

- (instancetype)initWithType:(NSString *)type;

@end

NS_ASSUME_NONNULL_END
