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
    [SentryMigrateSessionInit migrateSessionInit:@[]
                                envelopesDirPath:@"asdf"
                               envelopeFilePaths:@[]];
}

@end
