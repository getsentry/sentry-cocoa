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
#if !SDK_V10
    XCTAssertTrue(options.maskAllText);
#endif // !SDK_V10
#if !SDK_V10
    XCTAssertTrue(options.maskAllImages);
#endif // !SDK_V10
    XCTAssertTrue(options.enableViewRendererV2);
    XCTAssertFalse(options.enableFastViewRendering);

#if !SDK_V10
    XCTAssertEqual(options.maskedViewClasses.count, 0);
#endif // !SDK_V10
#if !SDK_V10
    XCTAssertEqual(options.unmaskedViewClasses.count, 0);
#endif // !SDK_V10
    XCTAssertEqual(options.quality, SentryReplayQualityMedium);
    XCTAssertEqual(options.frameRate, 1);
    XCTAssertEqual(options.errorReplayDuration, 30);
    XCTAssertEqual(options.sessionSegmentDuration, 5);
    XCTAssertEqual(options.maximumDuration, 60 * 60);

    // Currently there is not Obj-C SDK support for network details
    //  => assert it's turned off.
}

- (void)testInit_withAllArguments_shouldSetAllValues
{
    // This unit test uses the Swift constructor with default values to ensure the initializer stays
    // backwards-compatible with Objective-C, because any additional parameter (with and without
    // default values) will break the Objective-C compatibility.

    // -- Act --
#if SDK_V10
    SentryReplayOptions *options = [[SentryReplayOptions alloc] initWithSessionSampleRate:0.12f
                                                                        onErrorSampleRate:0.34f
                                                                     enableViewRendererV2:false
                                                                  enableFastViewRendering:true];
#else
    SentryReplayOptions *options = [[SentryReplayOptions alloc] initWithSessionSampleRate:0.12f
                                                                        onErrorSampleRate:0.34f
                                                                              maskAllText:false
                                                                            maskAllImages:false
                                                                     enableViewRendererV2:false
                                                                  enableFastViewRendering:true];
#endif // SDK_V10

    // -- Assert --
    XCTAssertEqual(options.sessionSampleRate, 0.12f);
    XCTAssertEqual(options.onErrorSampleRate, 0.34f);
#if !SDK_V10
    XCTAssertFalse(options.maskAllText);
#endif // !SDK_V10
#if !SDK_V10
    XCTAssertFalse(options.maskAllImages);
#endif // !SDK_V10
    XCTAssertFalse(options.enableViewRendererV2);
    XCTAssertTrue(options.enableFastViewRendering);

#if !SDK_V10
    XCTAssertEqual(options.maskedViewClasses.count, 0);
#endif // !SDK_V10
#if !SDK_V10
    XCTAssertEqual(options.unmaskedViewClasses.count, 0);
#endif // !SDK_V10
    XCTAssertEqual(options.quality, SentryReplayQualityMedium);
    XCTAssertEqual(options.frameRate, 1);
    XCTAssertEqual(options.errorReplayDuration, 30);
    XCTAssertEqual(options.sessionSegmentDuration, 5);
    XCTAssertEqual(options.maximumDuration, 60 * 60);

    // Currently there is not Obj-C SDK support for network details
    //  => assert it's turned off.
}

@end
