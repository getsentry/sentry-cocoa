#import "SentryObjC.h"
@import XCTest;

@interface SentryObjCAttachmentTests : XCTestCase
@end

@implementation SentryObjCAttachmentTests

- (void)testInitWithDataFilename_whenProvided_shouldCreateInstance
{
    // -- Arrange --
    NSData *data = [@"payload" dataUsingEncoding:NSUTF8StringEncoding];

    // -- Act --
    SentryObjCAttachment *attachment = [[SentryObjCAttachment alloc] initWithData:data
                                                                         filename:@"file.bin"];

    // -- Assert --
    XCTAssertNotNil(attachment);
    XCTAssertNotNil(attachment.data);
    XCTAssertEqualObjects(attachment.filename, @"file.bin");
    XCTAssertNil(attachment.path);
    XCTAssertEqual(attachment.attachmentType, SentryObjCAttachmentTypeEventAttachment);
}

- (void)testInitWithDataFilenameContentType_whenProvided_shouldSetContentType
{
    // -- Arrange --
    NSData *data = [@"payload" dataUsingEncoding:NSUTF8StringEncoding];

    // -- Act --
    SentryObjCAttachment *attachment =
        [[SentryObjCAttachment alloc] initWithData:data
                                          filename:@"file.json"
                                       contentType:@"application/json"];

    // -- Assert --
    XCTAssertNotNil(attachment);
    XCTAssertEqualObjects(attachment.filename, @"file.json");
    XCTAssertEqualObjects(attachment.contentType, @"application/json");
}

- (void)testInitWithPath_whenProvided_shouldCreateInstance
{
    // -- Arrange --
    NSData *data = [@"payload" dataUsingEncoding:NSUTF8StringEncoding];
    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"test-attach.txt"];
    [data writeToFile:tmpPath atomically:YES];

    // -- Act --
    SentryObjCAttachment *attachment = [[SentryObjCAttachment alloc] initWithPath:tmpPath];

    // -- Assert --
    XCTAssertNotNil(attachment);
    XCTAssertEqualObjects(attachment.path, tmpPath);
    XCTAssertNotNil(attachment.filename);
    XCTAssertNil(attachment.data);
}

- (void)testInitWithPathFilename_whenProvided_shouldSetFilename
{
    // -- Arrange --
    NSData *data = [@"payload" dataUsingEncoding:NSUTF8StringEncoding];
    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"test-attach.txt"];
    [data writeToFile:tmpPath atomically:YES];

    // -- Act --
    SentryObjCAttachment *attachment = [[SentryObjCAttachment alloc] initWithPath:tmpPath
                                                                         filename:@"custom.txt"];

    // -- Assert --
    XCTAssertNotNil(attachment);
    XCTAssertEqualObjects(attachment.path, tmpPath);
    XCTAssertEqualObjects(attachment.filename, @"custom.txt");
}

- (void)testInitWithPathFilenameContentType_whenProvided_shouldSetContentType
{
    // -- Arrange --
    NSData *data = [@"payload" dataUsingEncoding:NSUTF8StringEncoding];
    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"test-attach.txt"];
    [data writeToFile:tmpPath atomically:YES];

    // -- Act --
    SentryObjCAttachment *attachment = [[SentryObjCAttachment alloc] initWithPath:tmpPath
                                                                         filename:@"log.txt"
                                                                      contentType:@"text/plain"];

    // -- Assert --
    XCTAssertNotNil(attachment);
    XCTAssertEqualObjects(attachment.contentType, @"text/plain");
}

- (void)testInitWithDataFilenameContentTypeAttachmentType_whenViewHierarchy_shouldSetType
{
    // -- Arrange --
    NSData *data = [@"payload" dataUsingEncoding:NSUTF8StringEncoding];

    // -- Act --
    SentryObjCAttachment *attachment =
        [[SentryObjCAttachment alloc] initWithData:data
                                          filename:@"view.json"
                                       contentType:@"application/json"
                                    attachmentType:SentryObjCAttachmentTypeViewHierarchy];

    // -- Assert --
    XCTAssertNotNil(attachment);
    XCTAssertEqual(attachment.attachmentType, SentryObjCAttachmentTypeViewHierarchy);
}

- (void)testInitWithPathFilenameContentTypeAttachmentType_whenViewHierarchy_shouldSetAllProperties
{
    // -- Arrange --
    NSData *data = [@"payload" dataUsingEncoding:NSUTF8StringEncoding];
    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"test-attach.txt"];
    [data writeToFile:tmpPath atomically:YES];

    // -- Act --
    SentryObjCAttachment *attachment =
        [[SentryObjCAttachment alloc] initWithPath:tmpPath
                                          filename:@"hierarchy.json"
                                       contentType:@"application/json"
                                    attachmentType:SentryObjCAttachmentTypeViewHierarchy];

    // -- Assert --
    XCTAssertNotNil(attachment);
    XCTAssertEqualObjects(attachment.path, tmpPath);
    XCTAssertEqualObjects(attachment.filename, @"hierarchy.json");
    XCTAssertEqualObjects(attachment.contentType, @"application/json");
    XCTAssertEqual(attachment.attachmentType, SentryObjCAttachmentTypeViewHierarchy);
}

@end
