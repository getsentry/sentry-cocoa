#import "NSString+SentryUnsignedLongLongValue.h"
#import <XCTest/XCTest.h>

@interface SentryUnsignedLongLongValueTest : XCTestCase

@end

@implementation SentryUnsignedLongLongValueTest

- (void)testNSStringUnsignedLongLongValue
{
    XCTAssertEqual([@"" unsignedLongLongValue], 0);
    XCTAssertEqual([@"9" unsignedLongLongValue], 9);
    XCTAssertEqual([@"99" unsignedLongLongValue], 99);
    XCTAssertEqual([@"999" unsignedLongLongValue], 999);

    NSString *longLongMaxValue = [NSString stringWithFormat:@"%lu", 0x7FFFFFFFFFFFFFFF];
    XCTAssertEqual([longLongMaxValue unsignedLongLongValue], 9223372036854775807);

    NSString *negativelongLongMaxValue = [NSString stringWithFormat:@"%lu", -0x8000000000000000];
    XCTAssertEqual([negativelongLongMaxValue unsignedLongLongValue], 0x8000000000000000);

    NSString *unsignedLongLongMaxValue = [NSString stringWithFormat:@"%lu", 0xFFFFFFFFFFFFFFFF];
    XCTAssertEqual([unsignedLongLongMaxValue unsignedLongLongValue], 0xFFFFFFFFFFFFFFFF);
}

@end
