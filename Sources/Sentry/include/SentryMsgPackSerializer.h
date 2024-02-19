#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SentryStreameble

- (NSInputStream *)asInputStream;

- (NSInteger)streamSize;

@end

/**
 * This is a partial implementation of the MessagePack format.
 * We only need to concatenate a list of NSData into an envelope item.
 */
@interface SentryMsgPackSerializer : NSObject

+ (void)serializeDictionaryToMessagePack:
            (NSDictionary<NSString *, id<SentryStreameble>> *)dictionary
                                intoFile:(NSURL *)path;

@end

@interface
NSData (inputStreameble) <SentryStreameble>
@end

@interface
NSURL (inputStreameble) <SentryStreameble>
@end

NS_ASSUME_NONNULL_END
