#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SentryObjCAttributeContentType) {
    SentryObjCAttributeContentTypeString,
    SentryObjCAttributeContentTypeBoolean,
    SentryObjCAttributeContentTypeInteger,
    SentryObjCAttributeContentTypeDouble,
    SentryObjCAttributeContentTypeStringArray,
    SentryObjCAttributeContentTypeBooleanArray,
    SentryObjCAttributeContentTypeIntegerArray,
    SentryObjCAttributeContentTypeDoubleArray
};

/**
 * ObjC wrapper for SentryAttributeContent enum.
 */
@interface SentryObjCAttributeContent : NSObject

@property (nonatomic, readonly) SentryObjCAttributeContentType type;
@property (nonatomic, readonly, nullable) NSString *stringValue;
@property (nonatomic, readonly) BOOL booleanValue;
@property (nonatomic, readonly) NSInteger integerValue;
@property (nonatomic, readonly) double doubleValue;
@property (nonatomic, readonly, nullable) NSArray<NSString *> *stringArrayValue;
@property (nonatomic, readonly, nullable) NSArray<NSNumber *> *booleanArrayValue;
@property (nonatomic, readonly, nullable) NSArray<NSNumber *> *integerArrayValue;
@property (nonatomic, readonly, nullable) NSArray<NSNumber *> *doubleArrayValue;

+ (instancetype)stringWithValue:(NSString *)value;
+ (instancetype)booleanWithValue:(BOOL)value;
+ (instancetype)integerWithValue:(NSInteger)value;
+ (instancetype)doubleWithValue:(double)value;
+ (instancetype)stringArrayWithValue:(NSArray<NSString *> *)value;
+ (instancetype)booleanArrayWithValue:(NSArray<NSNumber *> *)value;
+ (instancetype)integerArrayWithValue:(NSArray<NSNumber *> *)value;
+ (instancetype)doubleArrayWithValue:(NSArray<NSNumber *> *)value;

@end

NS_ASSUME_NONNULL_END
