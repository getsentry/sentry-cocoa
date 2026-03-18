#import <Foundation/Foundation.h>

#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Type of attribute content value.
 */
typedef NS_ENUM(NSInteger, SentryAttributeContentType) {
    /// String value.
    SentryAttributeContentTypeString,
    /// Boolean value.
    SentryAttributeContentTypeBoolean,
    /// Integer value.
    SentryAttributeContentTypeInteger,
    /// Double-precision floating point value.
    SentryAttributeContentTypeDouble,
    /// Array of strings.
    SentryAttributeContentTypeStringArray,
    /// Array of booleans (as NSNumber).
    SentryAttributeContentTypeBooleanArray,
    /// Array of integers (as NSNumber).
    SentryAttributeContentTypeIntegerArray,
    /// Array of doubles (as NSNumber).
    SentryAttributeContentTypeDoubleArray
};

/**
 * Typed attribute content for custom event attributes.
 *
 * Wraps various value types (string, number, boolean, arrays) with type information
 * for structured event data. Use the factory methods to create instances.
 */
@interface SentryAttributeContent : NSObject

/// The type of value stored in this attribute.
@property (nonatomic, readonly) SentryAttributeContentType type;

/// The string value, if @c type is @c SentryAttributeContentTypeString.
@property (nonatomic, readonly, nullable) NSString *stringValue;

/// The boolean value, if @c type is @c SentryAttributeContentTypeBoolean.
@property (nonatomic, readonly) BOOL booleanValue;

/// The integer value, if @c type is @c SentryAttributeContentTypeInteger.
@property (nonatomic, readonly) NSInteger integerValue;

/// The double value, if @c type is @c SentryAttributeContentTypeDouble.
@property (nonatomic, readonly) double doubleValue;

/// The string array value, if @c type is @c SentryAttributeContentTypeStringArray.
@property (nonatomic, readonly, nullable) NSArray<NSString *> *stringArrayValue;

/// The boolean array value, if @c type is @c SentryAttributeContentTypeBooleanArray.
@property (nonatomic, readonly, nullable) NSArray<NSNumber *> *booleanArrayValue;

/// The integer array value, if @c type is @c SentryAttributeContentTypeIntegerArray.
@property (nonatomic, readonly, nullable) NSArray<NSNumber *> *integerArrayValue;

/// The double array value, if @c type is @c SentryAttributeContentTypeDoubleArray.
@property (nonatomic, readonly, nullable) NSArray<NSNumber *> *doubleArrayValue;

/**
 * Creates an attribute with a string value.
 *
 * @param value The string value.
 * @return A new attribute content instance.
 */
+ (instancetype)stringWithValue:(NSString *)value;

/**
 * Creates an attribute with a boolean value.
 *
 * @param value The boolean value.
 * @return A new attribute content instance.
 */
+ (instancetype)booleanWithValue:(BOOL)value;

/**
 * Creates an attribute with an integer value.
 *
 * @param value The integer value.
 * @return A new attribute content instance.
 */
+ (instancetype)integerWithValue:(NSInteger)value;

/**
 * Creates an attribute with a double value.
 *
 * @param value The double value.
 * @return A new attribute content instance.
 */
+ (instancetype)doubleWithValue:(double)value;

/**
 * Creates an attribute with a string array value.
 *
 * @param value The array of strings.
 * @return A new attribute content instance.
 */
+ (instancetype)stringArrayWithValue:(NSArray<NSString *> *)value;

/**
 * Creates an attribute with a boolean array value.
 *
 * @param value The array of booleans (as @c NSNumber).
 * @return A new attribute content instance.
 */
+ (instancetype)booleanArrayWithValue:(NSArray<NSNumber *> *)value;

/**
 * Creates an attribute with an integer array value.
 *
 * @param value The array of integers (as @c NSNumber).
 * @return A new attribute content instance.
 */
+ (instancetype)integerArrayWithValue:(NSArray<NSNumber *> *)value;

/**
 * Creates an attribute with a double array value.
 *
 * @param value The array of doubles (as @c NSNumber).
 * @return A new attribute content instance.
 */
+ (instancetype)doubleArrayWithValue:(NSArray<NSNumber *> *)value;

@end

NS_ASSUME_NONNULL_END
