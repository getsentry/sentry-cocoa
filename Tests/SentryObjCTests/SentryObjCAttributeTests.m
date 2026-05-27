#import "SentryObjC.h"
@import XCTest;

@interface SentryObjCAttributeTests : XCTestCase
@end

@implementation SentryObjCAttributeTests

- (void)testInitWithString_shouldSetTypeAndValue
{
    // -- Arrange --
    NSString *input = @"hello";

    // -- Act --
    SentryObjCAttribute *attr = [[SentryObjCAttribute alloc] initWithString:input];

    // -- Assert --
    XCTAssertNotNil(attr);
    XCTAssertEqualObjects(attr.type, @"string");
    XCTAssertEqualObjects(attr.value, @"hello");
}

- (void)testInitWithBoolean_shouldSetTypeAndValue
{
    // -- Act --
    SentryObjCAttribute *attr = [[SentryObjCAttribute alloc] initWithBoolean:YES];

    // -- Assert --
    XCTAssertNotNil(attr);
    XCTAssertEqualObjects(attr.type, @"boolean");
    XCTAssertNotNil(attr.value);
}

- (void)testInitWithInteger_shouldSetTypeAndValue
{
    // -- Act --
    SentryObjCAttribute *attr = [[SentryObjCAttribute alloc] initWithInteger:42];

    // -- Assert --
    XCTAssertNotNil(attr);
    XCTAssertEqualObjects(attr.type, @"integer");
    XCTAssertNotNil(attr.value);
}

- (void)testInitWithDouble_shouldSetTypeAndValue
{
    // -- Act --
    SentryObjCAttribute *attr = [[SentryObjCAttribute alloc] initWithDouble:3.14];

    // -- Assert --
    XCTAssertNotNil(attr);
    XCTAssertEqualObjects(attr.type, @"double");
    XCTAssertNotNil(attr.value);
}

- (void)testInitWithFloat_shouldSetDoubleTypeAndValue
{
    // -- Act --
    SentryObjCAttribute *attr = [[SentryObjCAttribute alloc] initWithFloat:2.5f];

    // -- Assert --
    XCTAssertNotNil(attr);
    XCTAssertEqualObjects(attr.type, @"double");
    XCTAssertNotNil(attr.value);
}

- (void)testInitWithStringArray_shouldSetTypeAndValue
{
    // -- Arrange --
    NSArray<NSString *> *values = @[ @"a", @"b", @"c" ];

    // -- Act --
    SentryObjCAttribute *attr = [[SentryObjCAttribute alloc] initWithStringArray:values];

    // -- Assert --
    XCTAssertNotNil(attr);
    XCTAssertEqualObjects(attr.type, @"string[]");
    XCTAssertNotNil(attr.value);
}

- (void)testInitWithBooleanArray_shouldSetTypeAndValue
{
    // -- Arrange --
    NSArray<NSNumber *> *values = @[ @YES, @NO, @YES ];

    // -- Act --
    SentryObjCAttribute *attr = [[SentryObjCAttribute alloc] initWithBooleanArray:values];

    // -- Assert --
    XCTAssertNotNil(attr);
    XCTAssertEqualObjects(attr.type, @"boolean[]");
    XCTAssertNotNil(attr.value);
}

- (void)testInitWithIntegerArray_shouldSetTypeAndValue
{
    // -- Arrange --
    NSArray<NSNumber *> *values = @[ @1, @2, @3 ];

    // -- Act --
    SentryObjCAttribute *attr = [[SentryObjCAttribute alloc] initWithIntegerArray:values];

    // -- Assert --
    XCTAssertNotNil(attr);
    XCTAssertEqualObjects(attr.type, @"integer[]");
    XCTAssertNotNil(attr.value);
}

- (void)testInitWithDoubleArray_shouldSetTypeAndValue
{
    // -- Arrange --
    NSArray<NSNumber *> *values = @[ @1.1, @2.2, @3.3 ];

    // -- Act --
    SentryObjCAttribute *attr = [[SentryObjCAttribute alloc] initWithDoubleArray:values];

    // -- Assert --
    XCTAssertNotNil(attr);
    XCTAssertEqualObjects(attr.type, @"double[]");
    XCTAssertNotNil(attr.value);
}

- (void)testInitWithFloatArray_shouldSetDoubleArrayTypeAndValue
{
    // -- Arrange --
    NSArray<NSNumber *> *values = @[ @1.0f, @2.0f ];

    // -- Act --
    SentryObjCAttribute *attr = [[SentryObjCAttribute alloc] initWithFloatArray:values];

    // -- Assert --
    XCTAssertNotNil(attr);
    XCTAssertEqualObjects(attr.type, @"double[]");
    XCTAssertNotNil(attr.value);
}

@end
