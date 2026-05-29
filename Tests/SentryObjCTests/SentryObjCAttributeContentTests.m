@import SentryObjC;
@import XCTest;

@interface SentryObjCAttributeContentTests : XCTestCase
@end

@implementation SentryObjCAttributeContentTests

- (void)testString_shouldSetTypeAndValue
{
    // -- Act --
    SentryObjCAttributeContent *content = [SentryObjCAttributeContent string:@"hello"];

    // -- Assert --
    XCTAssertNotNil(content);
    XCTAssertEqualObjects(content.type, @"string");
    XCTAssertEqualObjects(content.value, @"hello");
}

- (void)testBoolean_shouldSetTypeAndValue
{
    // -- Act --
    SentryObjCAttributeContent *content = [SentryObjCAttributeContent boolean:YES];

    // -- Assert --
    XCTAssertNotNil(content);
    XCTAssertEqualObjects(content.type, @"boolean");
    XCTAssertNotNil(content.value);
}

- (void)testInteger_shouldSetTypeAndValue
{
    // -- Act --
    SentryObjCAttributeContent *content = [SentryObjCAttributeContent integer:99];

    // -- Assert --
    XCTAssertNotNil(content);
    XCTAssertEqualObjects(content.type, @"integer");
    XCTAssertNotNil(content.value);
}

- (void)testDouble_shouldSetTypeAndValue
{
    // -- Act --
    SentryObjCAttributeContent *content = [SentryObjCAttributeContent double:1.23];

    // -- Assert --
    XCTAssertNotNil(content);
    XCTAssertEqualObjects(content.type, @"double");
    XCTAssertNotNil(content.value);
}

- (void)testStringArray_shouldSetTypeAndValue
{
    // -- Arrange --
    NSArray<NSString *> *values = @[ @"x", @"y" ];

    // -- Act --
    SentryObjCAttributeContent *content = [SentryObjCAttributeContent stringArray:values];

    // -- Assert --
    XCTAssertNotNil(content);
    XCTAssertEqualObjects(content.type, @"string[]");
    XCTAssertNotNil(content.value);
}

- (void)testBooleanArray_shouldSetTypeAndValue
{
    // -- Arrange --
    NSArray<NSNumber *> *values = @[ @YES, @NO ];

    // -- Act --
    SentryObjCAttributeContent *content = [SentryObjCAttributeContent booleanArray:values];

    // -- Assert --
    XCTAssertNotNil(content);
    XCTAssertEqualObjects(content.type, @"boolean[]");
    XCTAssertNotNil(content.value);
}

- (void)testIntegerArray_shouldSetTypeAndValue
{
    // -- Arrange --
    NSArray<NSNumber *> *values = @[ @10, @20 ];

    // -- Act --
    SentryObjCAttributeContent *content = [SentryObjCAttributeContent integerArray:values];

    // -- Assert --
    XCTAssertNotNil(content);
    XCTAssertEqualObjects(content.type, @"integer[]");
    XCTAssertNotNil(content.value);
}

- (void)testDoubleArray_shouldSetTypeAndValue
{
    // -- Arrange --
    NSArray<NSNumber *> *values = @[ @1.5, @2.5 ];

    // -- Act --
    SentryObjCAttributeContent *content = [SentryObjCAttributeContent doubleArray:values];

    // -- Assert --
    XCTAssertNotNil(content);
    XCTAssertEqualObjects(content.type, @"double[]");
    XCTAssertNotNil(content.value);
}

@end
