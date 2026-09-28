@import SentryObjC;
@import XCTest;
#import <TargetConditionals.h>

@interface SentryObjCExperimentalOptionsTests : XCTestCase
@end

@implementation SentryObjCExperimentalOptionsTests

#pragma mark - Init

- (void)testInit_shouldCreateInstance
{
    // -- Act --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];

    // -- Assert --
    XCTAssertNotNil(options);
}

#pragma mark - enableUnhandledCPPExceptionsV2

- (void)testEnableUnhandledCPPExceptionsV2_whenDefault_shouldBeFalse
{
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];

    // -- Assert --
    XCTAssertFalse(options.enableUnhandledCPPExceptionsV2);
}

- (void)testEnableUnhandledCPPExceptionsV2_whenSetToYes_shouldReturnTrue
{
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];

    // -- Act --
    options.enableUnhandledCPPExceptionsV2 = YES;

    // -- Assert --
    XCTAssertTrue(options.enableUnhandledCPPExceptionsV2);
}

- (void)testEnableUnhandledCPPExceptionsV2_whenSetToNo_shouldReturnFalse
{
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];
    options.enableUnhandledCPPExceptionsV2 = YES;

    // -- Act --
    options.enableUnhandledCPPExceptionsV2 = NO;

    // -- Assert --
    XCTAssertFalse(options.enableUnhandledCPPExceptionsV2);
}

#pragma mark - enableNewURLLoaderSwizzling

- (void)testEnableNewURLLoaderSwizzling_whenDefault_shouldBeFalse
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Assert --
    XCTAssertFalse(options.experimental.enableNewURLLoaderSwizzling);
}

- (void)testEnableNewURLLoaderSwizzling_whenToggled_shouldRetainValue
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.experimental.enableNewURLLoaderSwizzling = YES;

    // -- Assert --
    XCTAssertTrue(options.experimental.enableNewURLLoaderSwizzling);

    // -- Act --
    options.experimental.enableNewURLLoaderSwizzling = NO;

    // -- Assert --
    XCTAssertFalse(options.experimental.enableNewURLLoaderSwizzling);
}

#if (TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION) && SENTRY_OBJC_HAS_UIKIT
#    pragma mark - enableBreadcrumbTextExtraction

- (void)testEnableBreadcrumbTextExtraction_whenDefault_shouldBeFalse
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Assert --
    XCTAssertFalse(options.experimental.enableBreadcrumbTextExtraction);
}

- (void)testEnableBreadcrumbTextExtraction_whenToggled_shouldRetainValue
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.experimental.enableBreadcrumbTextExtraction = YES;

    // -- Assert --
    XCTAssertTrue(options.experimental.enableBreadcrumbTextExtraction);

    // -- Act --
    options.experimental.enableBreadcrumbTextExtraction = NO;

    // -- Assert --
    XCTAssertFalse(options.experimental.enableBreadcrumbTextExtraction);
}
#endif

#if !SDK_V10
#    pragma mark - enableWatchdogTerminationsV2

- (void)testEnableWatchdogTerminationsV2_whenDefault_shouldBeFalse
{
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];

#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // -- Assert --
    XCTAssertFalse(options.enableWatchdogTerminationsV2);
#    pragma clang diagnostic pop
}

- (void)testEnableWatchdogTerminationsV2_whenSetToYes_shouldReturnTrue
{
    // -- Arrange --
    SentryObjCExperimentalOptions *options = [[SentryObjCExperimentalOptions alloc] init];

#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // -- Act --
    options.enableWatchdogTerminationsV2 = YES;

    // -- Assert --
    XCTAssertTrue(options.enableWatchdogTerminationsV2);
#    pragma clang diagnostic pop
}
#endif

@end
