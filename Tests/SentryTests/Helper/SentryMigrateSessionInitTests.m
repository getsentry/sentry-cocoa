#import "SentryMigrateSessionInit.h"
#import "SentrySerialization.h"
#import "SentrySwift.h"
#import <XCTest/XCTest.h>

/**
 * Most of the tests are in SentryFileManagerTests.
 */
@interface SentryMigrateSessionInitTests : XCTestCase

@end

@implementation SentryMigrateSessionInitTests

- (void)testWithGarbageParametersDoesNotCrash
{
    SentryEnvelope *envelope = [DataDeserialization envelopeWithData:[[NSData alloc] init]];
    [SentryMigrateSessionInit migrateSessionInit:envelope
                                envelopesDirPath:@"asdf"
                               envelopeFilePaths:@[]];
}

@end
