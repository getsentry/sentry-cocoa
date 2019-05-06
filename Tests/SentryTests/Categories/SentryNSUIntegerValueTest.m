//
//  SentryNSUIntegerValueTest.m
//  SentryTests
//
//  Created by Crazy凡 on 2019/4/17.
//  Copyright © 2019 Sentry. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSString+SentryNSUIntegerValue.h"

@interface SentryNSUIntegerValueTest : XCTestCase

@end

@implementation SentryNSUIntegerValueTest

- (void)testNSStringUnsignedLongLongValue {
    XCTAssertEqual([@"" unsignedSentryLongLongValue], 0);
    XCTAssertEqual([@"9" unsignedSentryLongLongValue], 9);
    XCTAssertEqual([@"99" unsignedSentryLongLongValue], 99);
    XCTAssertEqual([@"999" unsignedSentryLongLongValue], 999);

    NSString *longLongMaxValue = [NSString stringWithFormat:@"%lu", 0x7FFFFFFFFFFFFFFF];
    XCTAssertEqual([longLongMaxValue unsignedSentryLongLongValue], 9223372036854775807);

    NSString *negativelongLongMaxValue = [NSString stringWithFormat:@"%lu", -0x8000000000000000];
    XCTAssertEqual([negativelongLongMaxValue unsignedSentryLongLongValue], 0x8000000000000000);

    NSString *unsignedLongLongMaxValue = [NSString stringWithFormat:@"%lu", 0xFFFFFFFFFFFFFFFF];
    XCTAssertEqual([unsignedLongLongMaxValue unsignedSentryLongLongValue], 0xFFFFFFFFFFFFFFFF );
}

@end
