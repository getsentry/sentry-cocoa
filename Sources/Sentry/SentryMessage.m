#import "SentryMessage.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

const NSUInteger MAX_STRING_LENGTH = 8192;

@implementation SentryMessage

- (instancetype)init
{
    return [super init];
}

+ (instancetype)messageWithFormatted:(NSString *_Nullable)formatted
{
    SentryMessage *message = [[SentryMessage alloc] init];
    message.formatted = formatted;
    return message;
}

- (void)setFormatted:(NSString *_Nullable)formatted
{
    if (nil != formatted && formatted.length > MAX_STRING_LENGTH) {
        _formatted = [formatted substringToIndex:MAX_STRING_LENGTH];
    } else {
        _formatted = formatted;
    }
}

- (void)setMessage:(NSString *_Nullable)message
{
    if (nil != message && message.length > MAX_STRING_LENGTH) {
        _message = [message substringToIndex:MAX_STRING_LENGTH];
    } else {
        _message = message;
    }
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = [[NSMutableDictionary alloc] init];

    [serializedData setValue:self.formatted forKey:@"formatted"];
    [serializedData setValue:self.message forKey:@"message"];
    [serializedData setValue:self.params forKey:@"params"];

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
