#import <Foundation/Foundation.h>

@protocol SentrySerializable;

NS_ASSUME_NONNULL_BEGIN

@interface SentryBooleanSerialization : NSObject

+ (void)testBooleanSerialization:(id<SentrySerializable>)serializable property:(NSString *)property;

+ (void)testBooleanSerialization:(id<SentrySerializable>)serializable
                        property:(NSString *)property
              serializedProperty:(NSString *)serializedProperty;

@end

NS_ASSUME_NONNULL_END
