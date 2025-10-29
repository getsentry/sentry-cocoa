#import "SentryRuntimeInit.h"
#import <XCTest/XCTest.h>

@interface SentryRuntimeInitTests : XCTestCase
@end

@implementation SentryRuntimeInitTests

- (void)testRuntimeInitTimestamp_IsInThePast
{
    // Arrange
    SentryRuntimeInit *sut = [[SentryRuntimeInit alloc] init];

    // Act
    NSDate *runtimeInit = sut.runtimeInitTimestamp;

    // Assert
    NSTimeInterval distance = [[NSDate date] timeIntervalSinceDate:runtimeInit];
    XCTAssertGreaterThan(distance, 0, @"Runtime init timestamp should be in the past");
}

- (void)testModuleInitializationTimestamp_IsInThePast
{
    // Arrange
    SentryRuntimeInit *sut = [[SentryRuntimeInit alloc] init];

    // Act
    NSDate *moduleInit = sut.moduleInitializationTimestamp;

    // Assert
    NSTimeInterval distance = [[NSDate date] timeIntervalSinceDate:moduleInit];
    XCTAssertGreaterThan(distance, 0, @"Module initialization timestamp should be in the past");
}

- (void)testRuntimeInitSystemTimestamp_IsNonZero
{
    // Arrange
    SentryRuntimeInit *sut = [[SentryRuntimeInit alloc] init];

    // Act
    uint64_t systemTimestamp = sut.runtimeInitSystemTimestamp;

    // Assert
    XCTAssertGreaterThan(systemTimestamp, 0, @"Runtime init system timestamp should be non-zero");
}

- (void)testModuleInitializationTimestamp_IsAfterRuntimeInit
{
    // Arrange
    SentryRuntimeInit *sut = [[SentryRuntimeInit alloc] init];

    // Act
    NSTimeInterval distance =
        [sut.moduleInitializationTimestamp timeIntervalSinceDate:sut.runtimeInitTimestamp];

    // Assert
    XCTAssertGreaterThan(distance, 0, @"Module initialization should happen after runtime init");
}

@end
