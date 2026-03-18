#import <Foundation/Foundation.h>

#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Type of attribute content value.
 */
typedef NS_ENUM(NSInteger, SentryObjCAttributeContentType) {
    /// String value.
    SentryObjCAttributeContentTypeString,
    /// Boolean value.
    SentryObjCAttributeContentTypeBoolean,
    /// Integer value.
    SentryObjCAttributeContentTypeInteger,
    /// Double-precision floating point value.
    SentryObjCAttributeContentTypeDouble,
    /// Array of strings.
    SentryObjCAttributeContentTypeStringArray,
    /// Array of booleans (as NSNumber).
    SentryObjCAttributeContentTypeBooleanArray,
    /// Array of integers (as NSNumber).
    SentryObjCAttributeContentTypeIntegerArray,
    /// Array of doubles (as NSNumber).
    SentryObjCAttributeContentTypeDoubleArray
};

/**
 * Typed attribute content for custom event attributes.
 *
 * Wraps various value types (string, number, boolean, arrays) with type information
 * for structured event data. Use the factory methods to create instances.
 */
@interface SentryObjCAttributeContent : NSObject

/// The type of value stored in this attribute.
@property (nonatomic, readonly) SentryObjCAttributeContentType type;

/// The string value, if @c type is @c SentryObjCAttributeContentTypeString.
@property (nonatomic, readonly, nullable) NSString *stringValue;

/// The boolean value, if @c type is @c SentryObjCAttributeContentTypeBoolean.
@property (nonatomic, readonly) BOOL booleanValue;

/// The integer value, if @c type is @c SentryObjCAttributeContentTypeInteger.
@property (nonatomic, readonly) NSInteger integerValue;

/// The double value, if @c type is @c SentryObjCAttributeContentTypeDouble.
@property (nonatomic, readonly) double doubleValue;

/// The string array value, if @c type is @c SentryObjCAttributeContentTypeStringArray.
@property (nonatomic, readonly, nullable) NSArray<NSString *> *stringArrayValue;

/// The boolean array value, if @c type is @c SentryObjCAttributeContentTypeBooleanArray.
@property (nonatomic, readonly, nullable) NSArray<NSNumber *> *booleanArrayValue;

/// The integer array value, if @c type is @c SentryObjCAttributeContentTypeIntegerArray.
@property (nonatomic, readonly, nullable) NSArray<NSNumber *> *integerArrayValue;

/// The double array value, if @c type is @c SentryObjCAttributeContentTypeDoubleArray.
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
