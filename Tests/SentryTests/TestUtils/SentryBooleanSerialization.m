#import "SentryBooleanSerialization.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryBooleanSerialization

+ (void)testBooleanSerialization:(id<SentrySerializable>)serializable property:(NSString *)property
{
    [SentryBooleanSerialization testBooleanSerialization:serializable
                                                property:property
                                      serializedProperty:property];
}

+ (void)testBooleanSerialization:(id<SentrySerializable>)serializable
                        property:(NSString *)property
              serializedProperty:(NSString *)serializedProperty
{
    NSString *selectorString =
        [NSString stringWithFormat:@"set%@%@:", [[property substringToIndex:1] uppercaseString],
                  [property substringFromIndex:1]];
    SEL selector = NSSelectorFromString(selectorString);
    NSAssert([serializable respondsToSelector:selector], @"Object doesn't have a property '%@'",
        property);

    NSInvocation *invocation = [NSInvocation
        invocationWithMethodSignature:[[serializable class]
                                          instanceMethodSignatureForSelector:selector]];
    [invocation setSelector:selector];
    [invocation setTarget:serializable];
    NSNumber *param1 = @2;
    [invocation setArgument:&param1 atIndex:2];
    [invocation invoke];

    NSDictionary *result = [serializable serialize];

    XCTAssertTrue(result[serializedProperty]);
    XCTAssertNotEqual(param1, result[serializedProperty]);
}

@end

NS_ASSUME_NONNULL_END
