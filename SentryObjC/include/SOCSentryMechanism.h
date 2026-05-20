#import <Foundation/Foundation.h>

@class SOCSentryMechanismContext;

NS_ASSUME_NONNULL_BEGIN

/// Metadata describing how an exception was reported.
@interface SOCSentryMechanism : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithType:(NSString *)type;

@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy, nullable) NSString *desc;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *data;
@property (nonatomic, strong, nullable) NSNumber *handled;
@property (nonatomic, strong, nullable) NSNumber *synthetic;
@property (nonatomic, copy, nullable) NSString *helpLink;
@property (nonatomic, strong, nullable) SOCSentryMechanismContext *meta;

@end

NS_ASSUME_NONNULL_END
