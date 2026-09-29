#import "SentryTests-Swift.h"
#import <XCTest/XCTest.h>

@interface SentryDictionaryDecoderObjCTests : XCTestCase

@end

@implementation SentryDictionaryDecoderObjCTests

#pragma mark - Bool

- (void)testBool_whenKeyIsMissing_shouldReturnNil
{
    // -- Arrange --
    NSDictionary *dictionary = @{ };

    // -- Act --
    NSNumber *result = [SentryDictionaryDecoderObjCHelper boolWithDictionary:dictionary
                                                                         key:@"missing"];

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testBool_whenValueIsNSNull_shouldReturnNil
{
    // -- Arrange --
    NSDictionary *dictionary = @{ @"value" : [NSNull null] };

    // -- Act --
    NSNumber *result = [SentryDictionaryDecoderObjCHelper boolWithDictionary:dictionary
                                                                         key:@"value"];

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testBool_whenValueIsNSNumberTrue_shouldReturnTrue
{
    // -- Arrange --
    NSDictionary *dictionary = @{ @"value" : @YES };

    // -- Act --
    NSNumber *result = [SentryDictionaryDecoderObjCHelper boolWithDictionary:dictionary
                                                                         key:@"value"];

    // -- Assert --
    XCTAssertEqualObjects(result, @YES);
}

- (void)testBool_whenValueIsNSNumberFalse_shouldReturnFalse
{
    // -- Arrange --
    NSDictionary *dictionary = @{ @"value" : @NO };

    // -- Act --
    NSNumber *result = [SentryDictionaryDecoderObjCHelper boolWithDictionary:dictionary
                                                                         key:@"value"];

    // -- Assert --
    XCTAssertEqualObjects(result, @NO);
}

- (void)testBool_whenValueIsNotNSNumber_shouldReturnNil
{
    // -- Arrange --
    NSDictionary *dictionary = @{ @"value" : @"true" };

    // -- Act --
    NSNumber *result = [SentryDictionaryDecoderObjCHelper boolWithDictionary:dictionary
                                                                         key:@"value"];

    // -- Assert --
    XCTAssertNil(result);
}

#pragma mark - Is Bool

- (void)testIsBool_whenObjCTypeIsChar_shouldReturnTrue
{
    // -- Arrange --
    NSNumber *number = @YES;
    XCTAssertEqualObjects([NSString stringWithUTF8String:number.objCType], @"c");

    // -- Act --
    BOOL result = [SentryDictionaryDecoderObjCHelper isBool:number];

    // -- Assert --
    XCTAssertTrue(result);
}

- (void)testIsBool_whenNumberIsCreatedFromObjCBool_shouldReturnTrue
{
    // -- Arrange --
    NSNumber *number = @((bool)true);
    XCTAssertEqualObjects([NSString stringWithUTF8String:number.objCType], @"c");

    // -- Act --
    BOOL result = [SentryDictionaryDecoderObjCHelper isBool:number];

    // -- Assert --
    XCTAssertTrue(result);
}

- (void)testIsBool_whenObjCTypeIsNotBool_shouldReturnFalse
{
    // -- Arrange --
    NSNumber *number = @1;

    // -- Act --
    BOOL result = [SentryDictionaryDecoderObjCHelper isBool:number];

    // -- Assert --
    XCTAssertFalse(result);
}

#pragma mark - UInt

- (void)testUInt_whenKeyIsMissing_shouldReturnNil
{
    // -- Arrange --
    NSDictionary *dictionary = @{ };

    // -- Act --
    NSNumber *result = [SentryDictionaryDecoderObjCHelper uintWithDictionary:dictionary
                                                                         key:@"missing"];

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testUInt_whenValueIsNSNull_shouldReturnNil
{
    // -- Arrange --
    NSDictionary *dictionary = @{ @"value" : [NSNull null] };

    // -- Act --
    NSNumber *result = [SentryDictionaryDecoderObjCHelper uintWithDictionary:dictionary
                                                                         key:@"value"];

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testUInt_whenValueIsNotNSNumber_shouldReturnNil
{
    // -- Arrange --
    NSDictionary *dictionary = @{ @"value" : @"1" };

    // -- Act --
    NSNumber *result = [SentryDictionaryDecoderObjCHelper uintWithDictionary:dictionary
                                                                         key:@"value"];

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testUInt_whenValueIsNegative_shouldReturnNil
{
    // -- Arrange --
    NSDictionary *dictionary = @{ @"value" : @(-1) };

    // -- Act --
    NSNumber *result = [SentryDictionaryDecoderObjCHelper uintWithDictionary:dictionary
                                                                         key:@"value"];

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testUInt_whenValueIsZero_shouldReturnZero
{
    // -- Arrange --
    NSDictionary *dictionary = @{ @"value" : @0 };

    // -- Act --
    NSNumber *result = [SentryDictionaryDecoderObjCHelper uintWithDictionary:dictionary
                                                                         key:@"value"];

    // -- Assert --
    XCTAssertEqualObjects(result, @0);
}

- (void)testUInt_whenValueIsPositive_shouldReturnUInt
{
    // -- Arrange --
    NSDictionary *dictionary = @{ @"value" : @42 };

    // -- Act --
    NSNumber *result = [SentryDictionaryDecoderObjCHelper uintWithDictionary:dictionary
                                                                         key:@"value"];

    // -- Assert --
    XCTAssertEqualObjects(result, @42);
}

#pragma mark - Dictionary

- (void)testDictionary_whenKeyIsMissing_shouldReturnNil
{
    // -- Arrange --
    NSDictionary *dictionary = @{ };

    // -- Act --
    NSDictionary *result = [SentryDictionaryDecoderObjCHelper dictionaryWithDictionary:dictionary
                                                                                   key:@"missing"];

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testDictionary_whenValueIsNSNull_shouldReturnNil
{
    // -- Arrange --
    NSDictionary *dictionary = @{ @"value" : [NSNull null] };

    // -- Act --
    NSDictionary *result = [SentryDictionaryDecoderObjCHelper dictionaryWithDictionary:dictionary
                                                                                   key:@"value"];

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testDictionary_whenValueIsDictionary_shouldReturnDictionary
{
    // -- Arrange --
    NSDictionary *expected = @{ @"nested" : @"value" };
    NSDictionary *dictionary = @{ @"value" : expected };

    // -- Act --
    NSDictionary *result = [SentryDictionaryDecoderObjCHelper dictionaryWithDictionary:dictionary
                                                                                   key:@"value"];

    // -- Assert --
    XCTAssertEqualObjects(result, expected);
}

- (void)testDictionary_whenValueIsNotDictionary_shouldReturnNil
{
    // -- Arrange --
    NSDictionary *dictionary = @{ @"value" : @[ @"nested" ] };

    // -- Act --
    NSDictionary *result = [SentryDictionaryDecoderObjCHelper dictionaryWithDictionary:dictionary
                                                                                   key:@"value"];

    // -- Assert --
    XCTAssertNil(result);
}

#pragma mark - Strings

- (void)testStrings_whenKeyIsMissing_shouldReturnNil
{
    // -- Arrange --
    NSDictionary *dictionary = @{ };

    // -- Act --
    NSArray *result = [SentryDictionaryDecoderObjCHelper stringsWithDictionary:dictionary
                                                                           key:@"missing"];

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testStrings_whenValueIsNSNull_shouldReturnNil
{
    // -- Arrange --
    NSDictionary *dictionary = @{ @"value" : [NSNull null] };

    // -- Act --
    NSArray *result = [SentryDictionaryDecoderObjCHelper stringsWithDictionary:dictionary
                                                                           key:@"value"];

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testStrings_whenValueIsNotArray_shouldReturnNil
{
    // -- Arrange --
    NSDictionary *dictionary = @{ @"value" : @"one" };

    // -- Act --
    NSArray *result = [SentryDictionaryDecoderObjCHelper stringsWithDictionary:dictionary
                                                                           key:@"value"];

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testStrings_whenValueIsStringArray_shouldReturnStrings
{
    // -- Arrange --
    NSDictionary *dictionary = @{ @"value" : @[ @"one", @"two" ] };

    // -- Act --
    NSArray *result = [SentryDictionaryDecoderObjCHelper stringsWithDictionary:dictionary
                                                                           key:@"value"];

    // -- Assert --
    XCTAssertEqualObjects(result, (@[ @"one", @"two" ]));
}

- (void)testStrings_whenArrayContainsNonStrings_shouldReturnOnlyStrings
{
    // -- Arrange --
    NSDictionary *dictionary = @{ @"value" : @[ @"one", @2, [NSNull null], @"three" ] };

    // -- Act --
    NSArray *result = [SentryDictionaryDecoderObjCHelper stringsWithDictionary:dictionary
                                                                           key:@"value"];

    // -- Assert --
    XCTAssertEqualObjects(result, (@[ @"one", @"three" ]));
}

@end
