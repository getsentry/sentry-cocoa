#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCAttribute : NSObject

@property (nonatomic, readonly, copy) NSString *type;
@property (nonatomic, readonly, strong) id value;

- (instancetype)initWithString:(NSString *)value;
- (instancetype)initWithBoolean:(BOOL)value;
- (instancetype)initWithInteger:(NSInteger)value;
- (instancetype)initWithDouble:(double)value;
- (instancetype)initWithFloat:(float)value;
- (instancetype)initWithStringArray:(NSArray<NSString *> *)values;
- (instancetype)initWithBooleanArray:(NSArray<NSNumber *> *)values;
- (instancetype)initWithIntegerArray:(NSArray<NSNumber *> *)values;
- (instancetype)initWithDoubleArray:(NSArray<NSNumber *> *)values;
- (instancetype)initWithFloatArray:(NSArray<NSNumber *> *)values;

@end

NS_ASSUME_NONNULL_END
