@import SentryObjC;
@import XCTest;

#pragma mark - Test target class

@interface SentryObjCSwizzleTestTarget : NSObject
- (NSInteger)value;
@end

@implementation SentryObjCSwizzleTestTarget
- (NSInteger)value
{
    return 7;
}
@end

@interface SentryObjCSwizzleOnceTarget : NSObject
- (void)noop;
@end

@implementation SentryObjCSwizzleOnceTarget
- (void)noop
{
}
@end

#pragma mark - Tests

@interface SentryObjCInternalSwizzleApiIntegrationTests : XCTestCase
@end

@implementation SentryObjCInternalSwizzleApiIntegrationTests

- (void)setUp
{
    [super setUp];
    [SentryObjCSDK startWithConfigureOptions:^(SentryObjCOptions *options) {
        options.dsn = @"https://key@sentry.io/123";
        options.enableCrashHandler = NO;
    }];
}

- (void)tearDown
{
    [SentryObjCSDK close];
    [super tearDown];
}

#pragma mark - Accessor

- (void)testInternal_swizzle_shouldBeAccessible
{
    // -- Act --
    SentryObjCInternalSwizzleApi *swizzle = SentryObjCSDK.internal.swizzle;

    // -- Assert --
    XCTAssertNotNil(swizzle);
}

#pragma mark - swizzleInstanceMethod

- (void)testSwizzleInstanceMethod_shouldSwizzleAndCallReplacement
{
    // -- Arrange --
    static const char key;
    __block BOOL replacementCalled = NO;

    // -- Act --
    BOOL result = [SentryObjCSDK.internal.swizzle
        swizzleInstanceMethod:@selector(value)
                      inClass:[SentryObjCSwizzleTestTarget class]
                         mode:SentryObjCSwizzleModeAlways
                          key:&key
                newImpFactory:^id(IMP(NS_NOESCAPE ^ getOriginal)(void)) {
                    return ^NSInteger(SentryObjCSwizzleTestTarget *target) {
                        replacementCalled = YES;
                        NSInteger (*original)(id, SEL) = (NSInteger (*)(id, SEL))getOriginal();
                        return original(target, @selector(value));
                    };
                }];

    SentryObjCSwizzleTestTarget *target = [[SentryObjCSwizzleTestTarget alloc] init];
    NSInteger value = [target value];

    // -- Assert --
    XCTAssertTrue(result);
    XCTAssertTrue(replacementCalled);
    XCTAssertEqual(value, 7);
}

- (void)testSwizzleInstanceMethod_oncePerClass_shouldReturnNoOnSecondSwizzle
{
    // -- Arrange --
    static const char key;
    id (^factory)(IMP(NS_NOESCAPE ^)(void)) = ^id(IMP(NS_NOESCAPE ^ getOriginal)(void)) {
        return ^(SentryObjCSwizzleOnceTarget *target) {
            void (*original)(id, SEL) = (void (*)(id, SEL))getOriginal();
            original(target, @selector(noop));
        };
    };

    // -- Act --
    BOOL first =
        [SentryObjCSDK.internal.swizzle swizzleInstanceMethod:@selector(noop)
                                                      inClass:[SentryObjCSwizzleOnceTarget class]
                                                         mode:SentryObjCSwizzleModeOncePerClass
                                                          key:&key
                                                newImpFactory:factory];
    BOOL second =
        [SentryObjCSDK.internal.swizzle swizzleInstanceMethod:@selector(noop)
                                                      inClass:[SentryObjCSwizzleOnceTarget class]
                                                         mode:SentryObjCSwizzleModeOncePerClass
                                                          key:&key
                                                newImpFactory:factory];

    // -- Assert --
    XCTAssertTrue(first);
    XCTAssertFalse(second);
}

#pragma mark - Mode enum

- (void)testSwizzleModeValues
{
    XCTAssertEqual(SentryObjCSwizzleModeAlways, 0);
    XCTAssertEqual(SentryObjCSwizzleModeOncePerClass, 1);
    XCTAssertEqual(SentryObjCSwizzleModeOncePerClassAndSuperclasses, 2);
}

@end
