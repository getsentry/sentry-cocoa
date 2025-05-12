#import "SentryOptions+Private.h"
#import <SentrySwift.h>
#import <XCTest/XCTest.h>

@interface SentryReplayOptionsObjcTests : XCTestCase

@end

@implementation SentryReplayOptionsObjcTests

- (void)testInit_withoutArguments_shouldUseDefaults
{
    // - `SentryReplayOptions` is a Swift class, therefore the preferred approach is an initializer
    // with default values to allow omission of arguments.
    // - Swift initializers with default values are not available in Objective-C.
    // - Therefore we have to explicitly provide a default constructor without any arguments.
    // - This test is to ensure that the default constructor works as the one with default values in
    // Swift.

    // -- Act --
    SentryReplayOptions *options = [[SentryReplayOptions alloc] init];

    // -- Assert --
    XCTAssertEqual(options.sessionSampleRate, 0);
    XCTAssertEqual(options.onErrorSampleRate, 0);
    XCTAssertTrue(options.maskAllText);
    XCTAssertTrue(options.maskAllImages);
    XCTAssertTrue(options.enableViewRendererV2);
    XCTAssertFalse(options.enableFastViewRendering);

    XCTAssertEqual(options.maskedViewClasses.count, 0);
    XCTAssertEqual(options.unmaskedViewClasses.count, 0);
    XCTAssertEqual(options.quality, SentryReplayQualityMedium);
    XCTAssertEqual(options.frameRate, 1);
    XCTAssertEqual(options.errorReplayDuration, 30);
    XCTAssertEqual(options.sessionSegmentDuration, 5);
    XCTAssertEqual(options.maximumDuration, 60 * 60);
}

@end
