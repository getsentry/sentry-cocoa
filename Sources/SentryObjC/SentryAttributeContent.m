#import "SentryAttributeContent.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryAttributeContent ()
@property (nonatomic, readwrite) SentryAttributeContentType type;
@property (nonatomic, readwrite, copy, nullable) NSString *stringValue;
@property (nonatomic, readwrite) BOOL booleanValue;
@property (nonatomic, readwrite) NSInteger integerValue;
@property (nonatomic, readwrite) double doubleValue;
@property (nonatomic, readwrite, copy, nullable) NSArray<NSString *> *stringArrayValue;
@property (nonatomic, readwrite, copy, nullable) NSArray<NSNumber *> *booleanArrayValue;
@property (nonatomic, readwrite, copy, nullable) NSArray<NSNumber *> *integerArrayValue;
@property (nonatomic, readwrite, copy, nullable) NSArray<NSNumber *> *doubleArrayValue;
@end

@implementation SentryAttributeContent

+ (instancetype)stringWithValue:(NSString *)value
{
    SentryAttributeContent *obj = [[SentryAttributeContent alloc] init];
    obj->_type = SentryAttributeContentTypeString;
    obj->_stringValue = [value copy];
    return obj;
}

+ (instancetype)booleanWithValue:(BOOL)value
{
    SentryAttributeContent *obj = [[SentryAttributeContent alloc] init];
    obj->_type = SentryAttributeContentTypeBoolean;
    obj->_booleanValue = value;
    return obj;
}

+ (instancetype)integerWithValue:(NSInteger)value
{
    SentryAttributeContent *obj = [[SentryAttributeContent alloc] init];
    obj->_type = SentryAttributeContentTypeInteger;
    obj->_integerValue = value;
    return obj;
}

+ (instancetype)doubleWithValue:(double)value
{
    SentryAttributeContent *obj = [[SentryAttributeContent alloc] init];
    obj->_type = SentryAttributeContentTypeDouble;
    obj->_doubleValue = value;
    return obj;
}

+ (instancetype)stringArrayWithValue:(NSArray<NSString *> *)value
{
    SentryAttributeContent *obj = [[SentryAttributeContent alloc] init];
    obj->_type = SentryAttributeContentTypeStringArray;
    obj->_stringArrayValue = [value copy];
    return obj;
}

+ (instancetype)booleanArrayWithValue:(NSArray<NSNumber *> *)value
{
    SentryAttributeContent *obj = [[SentryAttributeContent alloc] init];
    obj->_type = SentryAttributeContentTypeBooleanArray;
    obj->_booleanArrayValue = [value copy];
    return obj;
}

+ (instancetype)integerArrayWithValue:(NSArray<NSNumber *> *)value
{
    SentryAttributeContent *obj = [[SentryAttributeContent alloc] init];
    obj->_type = SentryAttributeContentTypeIntegerArray;
    obj->_integerArrayValue = [value copy];
    return obj;
}

+ (instancetype)doubleArrayWithValue:(NSArray<NSNumber *> *)value
{
    SentryAttributeContent *obj = [[SentryAttributeContent alloc] init];
    obj->_type = SentryAttributeContentTypeDoubleArray;
    obj->_doubleArrayValue = [value copy];
    return obj;
}

@end

NS_ASSUME_NONNULL_END
