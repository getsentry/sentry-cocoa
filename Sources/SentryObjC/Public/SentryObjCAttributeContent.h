#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * A type-safe representation of attribute values used by structured logging and metrics.
 *
 * @c SentryObjCAttributeContent provides factory methods for representing various attribute types
 * including strings, booleans, integers, doubles, and their array variants.
 */
@interface SentryObjCAttributeContent : NSObject
SENTRY_NO_INIT

/**
 * The type identifier for this attribute content.
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

/// The actual value stored in this attribute content.
@property (nonatomic, readonly, strong) id value;

/// Creates a string attribute content with the specified value.
+ (instancetype)string:(NSString *)value;
/// Creates a boolean attribute content with the specified value.
+ (instancetype)boolean:(BOOL)value;
/// Creates an integer attribute content with the specified value.
+ (instancetype)integer:(NSInteger)value;
/// Creates a double attribute content with the specified value.
+ (instancetype)double:(double)value;
/// Creates a string array attribute content with the specified values.
+ (instancetype)stringArray:(NSArray<NSString *> *)values;
/// Creates a boolean array attribute content with the specified values.
+ (instancetype)booleanArray:(NSArray<NSNumber *> *)values;
/// Creates an integer array attribute content with the specified values.
+ (instancetype)integerArray:(NSArray<NSNumber *> *)values;
/// Creates a double array attribute content with the specified values.
+ (instancetype)doubleArray:(NSArray<NSNumber *> *)values;

@end

NS_ASSUME_NONNULL_END
