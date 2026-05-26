#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A typed attribute that can be attached to structured item entries used by Logs & Metrics.
 *
 * @c SentryObjCAttribute provides a type-safe way to store structured data alongside item messages.
 * Supports String, Bool, Int, Double, Float types and their array variants.
 */
@interface SentryObjCAttribute : NSObject

/**
 * The type identifier for this attribute.
 *
 * Can be any of the following:
 * - @c string
 * - @c boolean
 * - @c integer
 * - @c double
 * - @c string[]
 * - @c boolean[]
 * - @c integer[]
 * - @c double[]
 */
@property (nonatomic, readonly, copy) NSString *type;

/// The actual value stored in this attribute.
@property (nonatomic, readonly, strong) id value;

/// Creates a string attribute with the specified value.
- (instancetype)initWithString:(NSString *)value;
/// Creates a boolean attribute with the specified value.
- (instancetype)initWithBoolean:(BOOL)value;
/// Creates an integer attribute with the specified value.
- (instancetype)initWithInteger:(NSInteger)value;
/// Creates a double attribute with the specified value.
- (instancetype)initWithDouble:(double)value;
/// Creates a double attribute from a float value.
- (instancetype)initWithFloat:(float)value;
/// Creates a string array attribute with the specified values.
- (instancetype)initWithStringArray:(NSArray<NSString *> *)values;
/// Creates a boolean array attribute with the specified values.
- (instancetype)initWithBooleanArray:(NSArray<NSNumber *> *)values;
/// Creates an integer array attribute with the specified values.
- (instancetype)initWithIntegerArray:(NSArray<NSNumber *> *)values;
/// Creates a double array attribute with the specified values.
- (instancetype)initWithDoubleArray:(NSArray<NSNumber *> *)values;
/// Creates a double array attribute from an array of float values.
- (instancetype)initWithFloatArray:(NSArray<NSNumber *> *)values;

@end

NS_ASSUME_NONNULL_END
