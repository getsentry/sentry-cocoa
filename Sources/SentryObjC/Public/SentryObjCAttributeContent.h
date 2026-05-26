#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCAttributeContent : NSObject

@property (nonatomic, readonly, copy) NSString *type;
@property (nonatomic, readonly, strong) id value;

+ (instancetype)string:(NSString *)value;
+ (instancetype)boolean:(BOOL)value;
+ (instancetype)integer:(NSInteger)value;
+ (instancetype)double:(double)value;
+ (instancetype)stringArray:(NSArray<NSString *> *)values;
+ (instancetype)booleanArray:(NSArray<NSNumber *> *)values;
+ (instancetype)integerArray:(NSArray<NSNumber *> *)values;
+ (instancetype)doubleArray:(NSArray<NSNumber *> *)values;

@end

NS_ASSUME_NONNULL_END
