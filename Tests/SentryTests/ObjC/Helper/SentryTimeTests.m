#import "SentryTime.h"
#import <XCTest/XCTest.h>

/**
 * There's an assertion that will crash these tests when trying degenerate inputs; we want to make
 * sure that we get the expected output in those cases in production when the assertion is compiled
 * out; therefore for this test class, we will no-op any assertions that are hit.
 */
@interface SentryTimeTestsAssertionHandler : NSAssertionHandler

@end

@implementation SentryTimeTestsAssertionHandler

- (void)handleFailureInFunction:(NSString *)functionName
                           file:(NSString *)fileName
                     lineNumber:(NSInteger)line
                    description:(NSString *)format, ...
{
    // no-op
}

- (void)handleFailureInMethod:(SEL)selector
                       object:(id)object
                         file:(NSString *)fileName
                   lineNumber:(NSInteger)line
                  description:(NSString *)format, ...
{
    // no-op
}

@end

@interface SentryTimeTests : XCTestCase

@end

@implementation SentryTimeTests

+ (void)setUp
{
    [[[NSThread currentThread] threadDictionary]
        setValue:[[SentryTimeTestsAssertionHandler alloc] init]
          forKey:NSAssertionHandlerKey];
}

+ (void)tearDown
{
    [[[NSThread currentThread] threadDictionary] setValue:nil forKey:NSAssertionHandlerKey];
}

- (void)testDuration
{
    XCTAssertEqual(getDurationNs(0, 1), 1);
    XCTAssertEqual(getDurationNs(1, 1), 0);
    XCTAssertEqual(getDurationNs(1, 7), 6);
    XCTAssertEqual(getDurationNs(0, UINT64_MAX), UINT64_MAX);

    // degenerate cases...

    // inputs that are not chronologically ordered always return 0
    XCTAssertEqual(getDurationNs(1, 0), 0);
    XCTAssertEqual(getDurationNs(UINT64_MAX, 0), 0);

    // negative inputs underflow and wrap around when converted to unsigned integers
    XCTAssertEqual(getDurationNs(0, -1), UINT64_MAX);
    XCTAssertEqual(getDurationNs(-1, 0), 0); // not chronologically ordered after underflow wrap!
    XCTAssertEqual(getDurationNs(-1, -1), 0);

    XCTAssertEqual(getDurationNs(0, -UINT64_MAX), 1);
    XCTAssertEqual(getDurationNs(-UINT64_MAX, 0), 0);
}

- (void)testChronologicOrderCheck
{
    XCTAssertTrue(orderedChronologically(0, 1));
    XCTAssertTrue(orderedChronologically(0, 5365));
    XCTAssertTrue(orderedChronologically(24, 7532564));

    XCTAssertFalse(orderedChronologically(1, 0));
    XCTAssertFalse(orderedChronologically(32431, 53));

    // we consider chronological order to be <=, so check equal inputs too
    XCTAssertTrue(orderedChronologically(0, 0));
    XCTAssertTrue(orderedChronologically(1, 1));
    XCTAssertTrue(orderedChronologically(UINT64_MAX, UINT64_MAX));

    // degenerate cases...

    // negative inputs underflow and wrap around when converted to unsigned integers
    XCTAssertTrue(orderedChronologically(0, -1));
    XCTAssertFalse(orderedChronologically(UINT64_MAX, -UINT64_MAX));

    XCTAssertFalse(orderedChronologically(-1, 0));
    XCTAssertTrue(orderedChronologically(-UINT64_MAX, UINT64_MAX));

    // should still work when they're equal negative inputs
    XCTAssertTrue(orderedChronologically(-1, -1));
    XCTAssertTrue(orderedChronologically(-UINT64_MAX, -UINT64_MAX));
}

@end
