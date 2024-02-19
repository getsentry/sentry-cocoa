#import "SentryMsgPackSerializer.h"

@implementation SentryMsgPackSerializer

+ (void)serializeDictionaryToMessagePack:(NSDictionary<NSString *, id<SentryStreameble>> *)dictionary intoFile:(NSURL *)path {
    NSOutputStream * outputStream = [[NSOutputStream alloc] initWithURL:path append:NO];
    
    uint8_t mapHeader = (uint8_t)(0x80 | dictionary.count);
    [outputStream write:&mapHeader maxLength:sizeof(uint8_t)];
    
    // Iterate over the map and serialize each key-value pair
    [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *key, id<SentryStreameble> value, BOOL *stop) {
        // Pack the key as a string
        NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
        uint8_t keyLength = (uint8_t)keyData.length;
        uint8_t str8Header = (uint8_t)0xD9;
        [outputStream write:&str8Header maxLength:sizeof(uint8_t)];
        [outputStream write:&keyLength maxLength:sizeof(uint8_t)];
        
        [outputStream write:keyData.bytes maxLength:keyData.length];
        
        // Pack the value as a binary string
        uint32_t valueLength = (uint32_t)[value streamSize];
        //We will always use the 4 bytes data length for simplicity.
        //Worst case we're losing 3 bytes.
        uint8_t bin32Header = (uint8_t)0xC6;
        [outputStream write:&bin32Header maxLength:sizeof(uint8_t)];
        valueLength = NSSwapHostIntToBig(valueLength);
        [outputStream write:(uint8_t*)&valueLength maxLength:sizeof(uint32_t)];
        
        NSInputStream * inputStream = [value asInputStream];
        [inputStream open];

        uint8_t buffer[1024];
        NSInteger bytesRead;

        while ([inputStream hasBytesAvailable]) {
            bytesRead = [inputStream read:buffer maxLength:sizeof(buffer)];
            if (bytesRead > 0) {
                [outputStream write:buffer maxLength:bytesRead];
            } else if (bytesRead < 0) {
                break;
            }
        }

        [inputStream close];
    }];
}

@end

@implementation NSURL (SentryStreameble)

- (NSInputStream *)asInputStream {
    return [[NSInputStream alloc] initWithURL:self];
}

- (NSInteger)streamSize {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDictionary *attributes = [fileManager attributesOfItemAtPath:self.path error:nil];
    NSNumber *fileSize = attributes[NSFileSize];
    return [fileSize unsignedIntegerValue];
}

@end

@implementation NSData (SentryStreameble)

- (NSInputStream *)asInputStream {
    return [[NSInputStream alloc] initWithData:self];
}

- (NSInteger)streamSize {
    return self.length;
}

@end
