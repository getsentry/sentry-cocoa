#import "SentryMigrateSessionInit.h"
#import "SentrySerialization.h"
#import <XCTest/XCTest.h>

/**
 * Most of the tests are in SentryFileManagerTests.
 */
@interface SentryMigrateSessionInitTests : XCTestCase

@end

@implementation SentryMigrateSessionInitTests

- (void)testWithGarbageParametersDoesNotCrash
{
    SentryEnvelope *envelope = [SentrySerialization envelopeWithData:[[NSData alloc] init]];
    [SentryMigrateSessionInit migrateSessionInit:envelope
                                envelopesDirPath:@"asdf"
                               envelopeFilePaths:@[]];
}

@end
