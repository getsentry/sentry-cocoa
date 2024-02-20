#import "SentryMsgPackSerializer.h"
#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

@interface SentryMsgPackSerializerTests : XCTestCase

@end

@implementation SentryMsgPackSerializerTests

- (void)testSerializeNSData
{
    NSURL *tempDirectoryURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    NSURL *tempFileURL = [tempDirectoryURL URLByAppendingPathComponent:@"test.dat"];

    NSDictionary<NSString *, id<SentryStreamable>> *dictionary = @{
        @"key1" : [@"Data 1" dataUsingEncoding:NSUTF8StringEncoding],
        @"key2" : [@"Data 2" dataUsingEncoding:NSUTF8StringEncoding]
    };

    BOOL result = [SentryMsgPackSerializer serializeDictionaryToMessagePack:dictionary intoFile:tempFileURL];
    XCTAssertTrue(result);
    NSData *tempFile = [NSData dataWithContentsOfURL:tempFileURL];
    [self assertMsgPack:tempFile];

    [[NSFileManager defaultManager] removeItemAtURL:tempFileURL error:nil];
}

- (void)testSerializeURL
{
    NSURL *tempDirectoryURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    NSURL *tempFileURL = [tempDirectoryURL URLByAppendingPathComponent:@"test.dat"];
    NSURL *file1URL = [tempDirectoryURL URLByAppendingPathComponent:@"file1.dat"];
    NSURL *file2URL = [tempDirectoryURL URLByAppendingPathComponent:@"file2.dat"];

    [@"File 1" writeToURL:file1URL atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [@"File 2" writeToURL:file2URL atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NSDictionary<NSString *, id<SentryStreamable>> *dictionary =
        @{ @"key1" : file1URL, @"key2" : file2URL };

    BOOL result = [SentryMsgPackSerializer serializeDictionaryToMessagePack:dictionary intoFile:tempFileURL];
    XCTAssertTrue(result);
    NSData *tempFile = [NSData dataWithContentsOfURL:tempFileURL];

    [self assertMsgPack:tempFile];

    [[NSFileManager defaultManager] removeItemAtURL:tempFileURL error:nil];
    [[NSFileManager defaultManager] removeItemAtURL:file1URL error:nil];
    [[NSFileManager defaultManager] removeItemAtURL:file2URL error:nil];
}

- (void)testSerializeInvalidFile {
    NSURL *tempDirectoryURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    NSURL *tempFileURL = [tempDirectoryURL URLByAppendingPathComponent:@"test.dat"];
    NSURL *file1URL = [tempDirectoryURL URLByAppendingPathComponent:@"notAFile.dat"];
    
    NSDictionary<NSString *, id<SentryStreamable>> *dictionary =
        @{ @"key1" : file1URL };

    BOOL result = [SentryMsgPackSerializer serializeDictionaryToMessagePack:dictionary intoFile:tempFileURL];
    XCTAssertFalse(result);
}

- (void)assertMsgPack:(NSData *)data
{
    NSInputStream *stream = [NSInputStream inputStreamWithData:data];
    [stream open];

    uint8_t buffer[1024];
    [stream read:buffer maxLength:1];

    XCTAssertEqual(buffer[0] & 0x80, 0x80); // Assert data is a dictionary

    uint8_t dicSize = buffer[0] & 0x0F; // Gets dictionary length

    for (int i = 0; i < dicSize; i++) { // for each item in the dictionary
        [stream read:buffer maxLength:1];
        XCTAssertEqual(buffer[0], (uint8_t)0xD9); // Asserts key is a string of up to 255
                                                  // characteres
        [stream read:buffer maxLength:1];
        uint8_t stringLen = buffer[0]; // Gets string length
        NSInteger read = [stream read:buffer maxLength:stringLen]; // read the key from the buffer
        buffer[read] = 0; // append a null terminator to the string
        NSString *key = [NSString stringWithCString:(char *)buffer encoding:NSUTF8StringEncoding];
        XCTAssertEqual(key.length, stringLen);

        [stream read:buffer maxLength:1];
        XCTAssertEqual(buffer[0], (uint8_t)0xC6);
        [stream read:buffer maxLength:sizeof(uint32_t)];
        uint32_t dataLen = NSSwapBigIntToHost(*(uint32_t *)buffer);
        [stream read:buffer maxLength:dataLen];
    }

    // We should be at the end of the data by now and nothing left to read
    NSInteger IsEndOfFile = [stream read:buffer maxLength:1];
    XCTAssertEqual(IsEndOfFile, 0);
}

@end
