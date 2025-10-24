#import <Foundation/Foundation.h>

@protocol SentryInternalSerializable;

NS_ASSUME_NONNULL_BEGIN

@interface SentryBooleanSerialization : NSObject

+ (void)testBooleanSerialization:(id<SentryInternalSerializable>)serializable property:(NSString *)property;

+ (void)testBooleanSerialization:(id<SentryInternalSerializable>)serializable
                        property:(NSString *)property
              serializedProperty:(NSString *)serializedProperty;

@end

NS_ASSUME_NONNULL_END
