@import XCTest;

#import "SentrySessionReplaySyncC.h"

#include <fcntl.h>
#include <unistd.h>

@interface SentrySessionReplaySyncCTests : XCTestCase
@end

@implementation SentrySessionReplaySyncCTests

- (void)testWriteAndReadInfo_shouldRoundTripReplayCheckpoint
{
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];

    sentrySessionReplaySync_start(path.UTF8String, 2);
    sentrySessionReplaySync_updateInfo(42, 123.5);
    sentrySessionReplaySync_writeInfo();

    SentryCrashReplay output = { 0 };
    XCTAssertTrue(sentrySessionReplaySync_readInfo(&output, path.UTF8String));
    XCTAssertEqual(output.segmentId, 42U);
    XCTAssertEqual(output.lastSegmentEnd, 123.5);
    XCTAssertEqual(output.replayType, 2U);
    unlink(path.UTF8String);
}

- (void)testReadInfo_whenCheckpointIsTruncated_shouldFailWithoutChangingOutput
{
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    const int fd = open(path.UTF8String, O_WRONLY | O_CREAT | O_TRUNC, 0600);
    XCTAssertGreaterThanOrEqual(fd, 0);
    const unsigned int segmentID = 42;
    XCTAssertEqual(write(fd, &segmentID, sizeof(segmentID)), sizeof(segmentID));
    close(fd);

    SentryCrashReplay output = { .segmentId = 7, .lastSegmentEnd = 8.5, .path = NULL };
    XCTAssertFalse(sentrySessionReplaySync_readInfo(&output, path.UTF8String));
    XCTAssertEqual(output.segmentId, 7U);
    XCTAssertEqual(output.lastSegmentEnd, 8.5);
    unlink(path.UTF8String);
}

@end
