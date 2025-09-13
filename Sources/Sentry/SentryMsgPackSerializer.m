#import "SentryMsgPackSerializer.h"
#import "SentryInternalDefines.h"
#import "SentryLogC.h"

@implementation SentryMsgPackSerializer

+ (BOOL)serializeDictionaryToMessagePack:
            (NSDictionary<NSString *, id<SentryStreamable>> *)dictionary
                                intoFile:(NSURL *)path
{
    NSOutputStream *outputStream = [[NSOutputStream alloc] initWithURL:path append:NO];
    [outputStream open];

    uint8_t mapHeader = (uint8_t)(0x80 | dictionary.count); // Map up to 15 elements
    [outputStream write:&mapHeader maxLength:sizeof(uint8_t)];

    for (NSString *key in dictionary) {
        id<SentryStreamable> value = dictionary[key];

        NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
        uint8_t str8Header = (uint8_t)0xD9; // String up to 255 characters
        uint8_t keyLength = (uint8_t)keyData.length;
        [outputStream write:&str8Header maxLength:sizeof(uint8_t)];
        [outputStream write:&keyLength maxLength:sizeof(uint8_t)];

        [outputStream write:keyData.bytes maxLength:keyData.length];

        NSInteger dataLength = [value streamSize];
        if (dataLength <= 0) {
            // MsgPack is being used strictly for session replay.
            // An item with a length of 0 will not be useful.
            // If we plan to use MsgPack for something else,
            // this needs to be re-evaluated.
            SENTRY_LOG_ERROR(@"Data for MessagePack dictionary has no content - Input: %@", value);
            return NO;
        }

        uint32_t valueLength = (uint32_t)dataLength;
        // We will always use the 4 bytes data length for simplicity.
        // Worst case we're losing 3 bytes.
        uint8_t bin32Header = (uint8_t)0xC6;
        [outputStream write:&bin32Header maxLength:sizeof(uint8_t)];
        valueLength = NSSwapHostIntToBig(valueLength);
        [outputStream write:(uint8_t *)&valueLength maxLength:sizeof(uint32_t)];

        NSInputStream *_Nullable nullableInputStream = [value asInputStream];
        if (nullableInputStream == nil) {
            SENTRY_LOG_ERROR(@"Could not get input stream - Input: %@", value);
            [outputStream close];
            return NO;
        }
        NSInputStream *_Nonnull inputStream
            = SENTRY_UNWRAP_NULLABLE(NSInputStream, nullableInputStream);
        [inputStream open];

        uint8_t buffer[1024];
        NSInteger bytesRead;

        while ([inputStream hasBytesAvailable]) {
            bytesRead = [inputStream read:buffer maxLength:sizeof(buffer)];
            if (bytesRead > 0) {
                [outputStream write:buffer maxLength:bytesRead];
            } else if (bytesRead < 0) {
                SENTRY_LOG_ERROR(@"Error reading bytes from input stream - Input: %@ - %li", value,
                    (long)bytesRead);

                [inputStream close];
                [outputStream close];
                return NO;
            }
        }

        [inputStream close];
    }
    [outputStream close];

    return YES;
}

@end

@implementation NSURL (SentryStreameble)

- (nullable NSInputStream *)asInputStream
{
    return [[NSInputStream alloc] initWithURL:self];
}

- (NSInteger)streamSize
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSString *_Nullable nullablePath = self.path;
    if (nullablePath == nil) {
        SENTRY_LOG_DEBUG(@"File URL has no path - File: %@", self);
        return -1;
    }
    NSDictionary *attributes =
        [fileManager attributesOfItemAtPath:SENTRY_UNWRAP_NULLABLE(NSString, nullablePath)
                                      error:&error];
    if (attributes == nil) {
        SENTRY_LOG_DEBUG(@"Could not read file attributes - File: %@ - %@", self, error);
        return -1;
    }
    NSNumber *fileSize = attributes[NSFileSize];
    return [fileSize unsignedIntegerValue];
}

@end

@implementation NSData (SentryStreameble)

- (nullable NSInputStream *)asInputStream
{
    return [[NSInputStream alloc] initWithData:self];
}

- (NSInteger)streamSize
{
    return self.length;
}

@end
