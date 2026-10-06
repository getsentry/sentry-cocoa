// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashString_Tests.m
//
//  Created by Karl Stenerud on 2013-01-26.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import <XCTest/XCTest.h>

#import "SentryCrashString.h"

@interface SentryCrashString_Tests : XCTestCase
@end

@implementation SentryCrashString_Tests

- (void)testExtractHexValue
{
    const char *string = "Some string with 0x12345678 and such";
    uint64_t expected = 0x12345678;
    uint64_t result = 0;
    bool success = sentrycrashstring_extractHexValue(string, (int)strlen(string), &result);
    XCTAssertTrue(success, @"");
    XCTAssertEqual(result, expected, @"");
}

- (void)testExtractHexValue2
{
    const char *string = "Some string with 0x1 and such";
    uint64_t expected = 0x1;
    uint64_t result = 0;
    bool success = sentrycrashstring_extractHexValue(string, (int)strlen(string), &result);
    XCTAssertTrue(success, @"");
    XCTAssertEqual(result, expected, @"");
}

- (void)testExtractHexValue3
{
    const char *string = "Some string with 0x1234567890123456 and such";
    uint64_t expected = 0x1234567890123456;
    uint64_t result = 0;
    bool success = sentrycrashstring_extractHexValue(string, (int)strlen(string), &result);
    XCTAssertTrue(success, @"");
    XCTAssertEqual(result, expected, @"");
}

- (void)testExtractHexValueBeginning
{
    const char *string = "0x12345678 Some string";
    uint64_t expected = 0x12345678;
    uint64_t result = 0;
    bool success = sentrycrashstring_extractHexValue(string, (int)strlen(string), &result);
    XCTAssertTrue(success, @"");
    XCTAssertEqual(result, expected, @"");
}

- (void)testExtractHexValueEnd
{
    const char *string = "Some string with 0x12345678";
    uint64_t expected = 0x12345678;
    uint64_t result = 0;
    bool success = sentrycrashstring_extractHexValue(string, (int)strlen(string), &result);
    XCTAssertTrue(success, @"");
    XCTAssertEqual(result, expected, @"");
}

- (void)testExtractHexValueEmpty
{
    const char *string = "";
    uint64_t result = 0;
    bool success = sentrycrashstring_extractHexValue(string, (int)strlen(string), &result);
    XCTAssertFalse(success, @"");
}

- (void)testExtractHexValueInvalid
{
    const char *string = "Some string with 0xoo and such";
    uint64_t result = 0;
    bool success = sentrycrashstring_extractHexValue(string, (int)strlen(string), &result);
    XCTAssertFalse(success, @"");
}

- (void)testExtractHexValueInvalid2
{
    const char *string = "Some string with 0xoo";
    uint64_t result = 0;
    bool success = sentrycrashstring_extractHexValue(string, (int)strlen(string), &result);
    XCTAssertFalse(success, @"");
}

- (void)testIsNullTerminatedUTF8String
{
    const char *string = "A string";
    bool success = sentrycrashstring_isNullTerminatedUTF8String(string, 2, 100);
    XCTAssertTrue(success, @"");
}

- (void)testIsNullTerminatedUTF8String2
{
    const char *string = "テスト";
    bool success = sentrycrashstring_isNullTerminatedUTF8String(string, 2, 100);
    XCTAssertTrue(success, @"");
}

- (void)testIsNullTerminatedUTF8String3
{
    const char *string = "aŸঠ𐅐 and so on";
    bool success = sentrycrashstring_isNullTerminatedUTF8String(string, 2, 100);
    XCTAssertTrue(success, @"");
}

- (void)testIsNullTerminatedUTF8StringTooShort
{
    const char *string = "A string";
    bool success = sentrycrashstring_isNullTerminatedUTF8String(string, 10, 100);
    XCTAssertFalse(success, @"");
}

- (void)testIsNullTerminatedUTF8StringTooLong
{
    const char *string = "A string";
    bool success = sentrycrashstring_isNullTerminatedUTF8String(string, 2, 5);
    XCTAssertFalse(success, @"");
}

- (void)testIsNullTerminatedUTF8StringInvalid
{
    const char *string = "A string\xf8";
    bool success = sentrycrashstring_isNullTerminatedUTF8String(string, 2, 100);
    XCTAssertFalse(success, @"");
}

- (void)testIsNullTerminatedUTF8StringInvalid2
{
    const char *string = "A string\xc1zzz";
    bool success = sentrycrashstring_isNullTerminatedUTF8String(string, 2, 100);
    XCTAssertFalse(success, @"");
}

- (void)testIsNullTerminatedUTF8StringInvalid3
{
    const char *string = "\xc0";
    bool success = sentrycrashstring_isNullTerminatedUTF8String(string, 1, 1);
    XCTAssertFalse(success, @"");
}

- (void)testIsNullTerminatedUTF8StringInvalid4
{
    const char *string = "blah \x80";
    bool success = sentrycrashstring_isNullTerminatedUTF8String(string, 1, 100);
    XCTAssertFalse(success, @"");
}

- (void)testIsNullTerminatedUTF8StringInvalid5
{
    const char *string = "\x01\x02\x03";
    bool success = sentrycrashstring_isNullTerminatedUTF8String(string, 2, 100);
    XCTAssertFalse(success, @"");
}

- (void)testAddressToString
{
    char buffer[32];
    int length = sentrycrashstring_addressToString(buffer, sizeof(buffer), 0x1234abcd);

    XCTAssertEqual(length, 10);
    XCTAssertEqual(strcmp(buffer, "0x1234abcd"), 0);
}

- (void)testAddressToString_BufferTooSmall
{
    char buffer[4];
    int length = sentrycrashstring_addressToString(buffer, sizeof(buffer), 0x1234abcd);

    XCTAssertEqual(length, -1);
    XCTAssertEqual(buffer[0], '\0');
}

- (void)testInt64ToString_Int64Limits
{
    char minBuffer[32];
    char maxBuffer[32];

    XCTAssertEqual(sentrycrashstring_int64ToString(minBuffer, sizeof(minBuffer), INT64_MIN), 20);
    XCTAssertEqual(sentrycrashstring_int64ToString(maxBuffer, sizeof(maxBuffer), INT64_MAX), 19);
    XCTAssertEqual(strcmp(minBuffer, "-9223372036854775808"), 0);
    XCTAssertEqual(strcmp(maxBuffer, "9223372036854775807"), 0);
}

- (void)testUInt64ToString_UInt64Max
{
    char buffer[32];
    int length = sentrycrashstring_uint64ToString(buffer, sizeof(buffer), UINT64_MAX);

    XCTAssertEqual(length, 20);
    XCTAssertEqual(strcmp(buffer, "18446744073709551615"), 0);
}

- (void)testDoubleToString
{
    char buffer[64];

    XCTAssertEqual(sentrycrashstring_doubleToString(buffer, sizeof(buffer), -0.2), 4);
    XCTAssertEqual(strcmp(buffer, "-0.2"), 0);

    XCTAssertEqual(sentrycrashstring_doubleToString(buffer, sizeof(buffer), -2e-15), 6);
    XCTAssertEqual(strcmp(buffer, "-2e-15"), 0);

    XCTAssertEqual(sentrycrashstring_doubleToString(buffer, sizeof(buffer), 123.456789), 7);
    XCTAssertEqual(strcmp(buffer, "123.457"), 0);

    XCTAssertEqual(sentrycrashstring_doubleToString(buffer, sizeof(buffer), 100000), 6);
    XCTAssertEqual(strcmp(buffer, "100000"), 0);

    XCTAssertEqual(sentrycrashstring_doubleToString(buffer, sizeof(buffer), 123000), 6);
    XCTAssertEqual(strcmp(buffer, "123000"), 0);
}

@end
