#import "SentryObjCAttributeContent.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCAttributeContent ()
@property (nonatomic, readwrite) SentryObjCAttributeContentType type;
@property (nonatomic, readwrite, copy, nullable) NSString *stringValue;
@property (nonatomic, readwrite) BOOL booleanValue;
@property (nonatomic, readwrite) NSInteger integerValue;
@property (nonatomic, readwrite) double doubleValue;
@property (nonatomic, readwrite, copy, nullable) NSArray<NSString *> *stringArrayValue;
@property (nonatomic, readwrite, copy, nullable) NSArray<NSNumber *> *booleanArrayValue;
@property (nonatomic, readwrite, copy, nullable) NSArray<NSNumber *> *integerArrayValue;
@property (nonatomic, readwrite, copy, nullable) NSArray<NSNumber *> *doubleArrayValue;
@end

@implementation SentryObjCAttributeContent

+ (instancetype)stringWithValue:(NSString *)value
{
    SentryObjCAttributeContent *obj = [[SentryObjCAttributeContent alloc] init];
    obj->_type = SentryObjCAttributeContentTypeString;
    obj->_stringValue = [value copy];
    return obj;
}

+ (instancetype)booleanWithValue:(BOOL)value
{
    SentryObjCAttributeContent *obj = [[SentryObjCAttributeContent alloc] init];
    obj->_type = SentryObjCAttributeContentTypeBoolean;
    obj->_booleanValue = value;
    return obj;
}

+ (instancetype)integerWithValue:(NSInteger)value
{
    SentryObjCAttributeContent *obj = [[SentryObjCAttributeContent alloc] init];
    obj->_type = SentryObjCAttributeContentTypeInteger;
    obj->_integerValue = value;
    return obj;
}

+ (instancetype)doubleWithValue:(double)value
{
    SentryObjCAttributeContent *obj = [[SentryObjCAttributeContent alloc] init];
    obj->_type = SentryObjCAttributeContentTypeDouble;
    obj->_doubleValue = value;
    return obj;
}

+ (instancetype)stringArrayWithValue:(NSArray<NSString *> *)value
{
    SentryObjCAttributeContent *obj = [[SentryObjCAttributeContent alloc] init];
    obj->_type = SentryObjCAttributeContentTypeStringArray;
    obj->_stringArrayValue = [value copy];
    return obj;
}

+ (instancetype)booleanArrayWithValue:(NSArray<NSNumber *> *)value
{
    SentryObjCAttributeContent *obj = [[SentryObjCAttributeContent alloc] init];
    obj->_type = SentryObjCAttributeContentTypeBooleanArray;
    obj->_booleanArrayValue = [value copy];
    return obj;
}

+ (instancetype)integerArrayWithValue:(NSArray<NSNumber *> *)value
{
    SentryObjCAttributeContent *obj = [[SentryObjCAttributeContent alloc] init];
    obj->_type = SentryObjCAttributeContentTypeIntegerArray;
    obj->_integerArrayValue = [value copy];
    return obj;
}

+ (instancetype)doubleArrayWithValue:(NSArray<NSNumber *> *)value
{
    SentryObjCAttributeContent *obj = [[SentryObjCAttributeContent alloc] init];
    obj->_type = SentryObjCAttributeContentTypeDoubleArray;
    obj->_doubleArrayValue = [value copy];
    return obj;
}

@end

NS_ASSUME_NONNULL_END
