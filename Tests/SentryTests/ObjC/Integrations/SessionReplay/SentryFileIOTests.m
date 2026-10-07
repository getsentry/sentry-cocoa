@import XCTest;

#import "SentryFileIO.h"

#include <pthread.h>
#include <signal.h>
#include <string.h>
#include <unistd.h>

static void
sentryFileIOTests_signalHandler(__unused int signal)
{
}

@interface SentryFileIOTests : XCTestCase
@end

@implementation SentryFileIOTests

- (void)testReadBytesFromFD_whenWritesArePartial_shouldReadAllBytes
{
    int pipeFDs[2];
    XCTAssertEqual(pipe(pipeFDs), 0);

    const char first[] = "abc";
    XCTAssertEqual(write(pipeFDs[1], first, sizeof(first) - 1), sizeof(first) - 1);

    const int writeFD = pipeFDs[1];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        usleep(10 * 1000);
        write(writeFD, "def", 3);
        close(writeFD);
    });

    char output[6] = { 0 };
    XCTAssertTrue(sentryFileIO_readBytesFromFD(pipeFDs[0], output, sizeof(output)));
    XCTAssertEqual(memcmp(output, "abcdef", sizeof(output)), 0);
    close(pipeFDs[0]);
}

- (void)testWriteBytesToFD_whenWriteIsLargerThanPipeCapacity_shouldWriteAllBytes
{
    int pipeFDs[2];
    XCTAssertEqual(pipe(pipeFDs), 0);

    NSMutableData *expected = [NSMutableData dataWithLength:1024 * 1024];
    memset(expected.mutableBytes, 0x5a, expected.length);
    NSMutableData *actual = [NSMutableData dataWithLength:expected.length];
    XCTestExpectation *readFinished = [self expectationWithDescription:@"read all bytes"];

    const int readFD = pipeFDs[0];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        size_t position = 0;
        while (position < actual.length) {
            const ssize_t count
                = read(readFD, (char *)actual.mutableBytes + position, actual.length - position);
            if (count <= 0) {
                break;
            }
            position += (size_t)count;
        }
        close(readFD);
        [readFinished fulfill];
    });

    XCTAssertTrue(sentryFileIO_writeBytesToFD(pipeFDs[1], expected.bytes, expected.length));
    close(pipeFDs[1]);
    [self waitForExpectations:@[ readFinished ] timeout:2];
    XCTAssertEqualObjects(actual, expected);
}

- (void)testReadBytesFromFD_whenReadIsInterrupted_shouldRetry
{
    int pipeFDs[2];
    XCTAssertEqual(pipe(pipeFDs), 0);

    struct sigaction action = { 0 };
    action.sa_handler = sentryFileIOTests_signalHandler;
    sigemptyset(&action.sa_mask);
    struct sigaction previousAction = { 0 };
    XCTAssertEqual(sigaction(SIGUSR1, &action, &previousAction), 0);

    const pthread_t testThread = pthread_self();
    const int writeFD = pipeFDs[1];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        usleep(10 * 1000);
        pthread_kill(testThread, SIGUSR1);
        usleep(10 * 1000);
        write(writeFD, "a", 1);
        close(writeFD);
    });

    char output = 0;
    XCTAssertTrue(sentryFileIO_readBytesFromFD(pipeFDs[0], &output, sizeof(output)));
    XCTAssertEqual(output, 'a');
    close(pipeFDs[0]);
    XCTAssertEqual(sigaction(SIGUSR1, &previousAction, NULL), 0);
}

- (void)testReadBytesFromFD_whenFileEndsEarly_shouldFail
{
    int pipeFDs[2];
    XCTAssertEqual(pipe(pipeFDs), 0);
    XCTAssertEqual(write(pipeFDs[1], "a", 1), 1);
    close(pipeFDs[1]);

    char output[2] = { 0 };
    XCTAssertFalse(sentryFileIO_readBytesFromFD(pipeFDs[0], output, sizeof(output)));
    close(pipeFDs[0]);
}

- (void)testReadBytesFromFD_whenFileDescriptorIsInvalid_shouldFail
{
    char output = 0;
    XCTAssertFalse(sentryFileIO_readBytesFromFD(-1, &output, sizeof(output)));
}

- (void)testWriteBytesToFD_whenFileDescriptorIsInvalid_shouldFail
{
    const char input = 'a';
    XCTAssertFalse(sentryFileIO_writeBytesToFD(-1, &input, sizeof(input)));
}

- (void)testReadAndWriteBytesToFD_whenLengthIsZero_shouldSucceed
{
    XCTAssertTrue(sentryFileIO_readBytesFromFD(-1, NULL, 0));
    XCTAssertTrue(sentryFileIO_writeBytesToFD(-1, NULL, 0));
}

@end
