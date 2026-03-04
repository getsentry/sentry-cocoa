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

    XCTAssertNotNil(options.networkDetailAllowUrls);
    XCTAssertEqual(options.networkDetailAllowUrls.count, 0);
    XCTAssertNotNil(options.networkDetailDenyUrls);
    XCTAssertEqual(options.networkDetailDenyUrls.count, 0);
    XCTAssertTrue(options.networkCaptureBodies);
}

- (void)testInit_withAllArguments_shouldSetAllValues
{
    // This unit test uses the Swift constructor with default values to ensure the initializer stays
    // backwards-compatible with Objective-C, because any additional parameter (with and without
    // default values) will break the Objective-C compatibility.

    // -- Act --
    SentryReplayOptions *options = [[SentryReplayOptions alloc] initWithSessionSampleRate:0.12f
                                                                        onErrorSampleRate:0.34f
                                                                              maskAllText:false
                                                                            maskAllImages:false
                                                                     enableViewRendererV2:false
                                                                  enableFastViewRendering:true];

    // -- Assert --
    XCTAssertEqual(options.sessionSampleRate, 0.12f);
    XCTAssertEqual(options.onErrorSampleRate, 0.34f);
    XCTAssertFalse(options.maskAllText);
    XCTAssertFalse(options.maskAllImages);
    XCTAssertFalse(options.enableViewRendererV2);
    XCTAssertTrue(options.enableFastViewRendering);

    XCTAssertEqual(options.maskedViewClasses.count, 0);
    XCTAssertEqual(options.unmaskedViewClasses.count, 0);
    XCTAssertEqual(options.quality, SentryReplayQualityMedium);
    XCTAssertEqual(options.frameRate, 1);
    XCTAssertEqual(options.errorReplayDuration, 30);
    XCTAssertEqual(options.sessionSegmentDuration, 5);
    XCTAssertEqual(options.maximumDuration, 60 * 60);
    XCTAssertNotNil(options.networkDetailAllowUrls);
    XCTAssertEqual(options.networkDetailAllowUrls.count, 0);
    XCTAssertNotNil(options.networkDetailDenyUrls);
    XCTAssertEqual(options.networkDetailDenyUrls.count, 0);
    XCTAssertTrue(options.networkCaptureBodies);
    XCTAssertEqualObjects(options.networkRequestHeaders, (@[@"Content-Type", @"Content-Length", @"Accept"]));
    XCTAssertEqualObjects(options.networkResponseHeaders, (@[@"Content-Type", @"Content-Length", @"Accept"]));
}

// MARK: - Network Details Tests (Objective-C Regex Interoperability)

- (void)testIsNetworkDetailCaptureEnabled_withStringPatterns_shouldUseSubstringMatching
{
    // -- Arrange --
    NSDictionary *config = @{
        @"networkDetailAllowUrls": @[ @"api.example.com", @"/analytics/", @"track" ],
        @"networkDetailDenyUrls": @[]
    };
    SentryReplayOptions *options = [[SentryReplayOptions alloc] initWithDictionary:config];

    // -- Act & Assert --
    // Should match - substring found anywhere in URL
    XCTAssertTrue([options isNetworkDetailCaptureEnabledFor:@"https://api.example.com/users"]);
    XCTAssertTrue([options isNetworkDetailCaptureEnabledFor:@"https://sub.api.example.com/data"]);
    XCTAssertTrue([options isNetworkDetailCaptureEnabledFor:@"https://myapp.com/v1/analytics/events"]);
    XCTAssertTrue([options isNetworkDetailCaptureEnabledFor:@"https://site.com/track/user"]);
    XCTAssertTrue([options isNetworkDetailCaptureEnabledFor:@"https://tracking.service.com/api"]);

    // Should NOT match - substring not found
    XCTAssertFalse([options isNetworkDetailCaptureEnabledFor:@"https://other.example.com"]);
    XCTAssertFalse([options isNetworkDetailCaptureEnabledFor:@"https://api.other.com"]);
    XCTAssertFalse([options isNetworkDetailCaptureEnabledFor:@"https://analyze.com/data"]);
}

- (void)testIsNetworkDetailCaptureEnabled_withNSRegularExpression_shouldUseProvidedRegexMatching
{
    // -- Arrange --
    NSError *error = nil;
    NSRegularExpression *regularRegex =
        [NSRegularExpression regularExpressionWithPattern:@"^https://api\\.example\\.com/.*"
                                                  options:0
                                                    error:&error];
    XCTAssertNil(error);

    NSRegularExpression *caseInsensitiveRegex =
        [NSRegularExpression regularExpressionWithPattern:@"^https://analytics\\."
                                                  options:NSRegularExpressionCaseInsensitive
                                                    error:&error];
    XCTAssertNil(error);

    NSDictionary *config = @{
        @"networkDetailAllowUrls": @[ regularRegex, caseInsensitiveRegex ],
        @"networkDetailDenyUrls": @[]
    };
    SentryReplayOptions *options = [[SentryReplayOptions alloc] initWithDictionary:config];

    // -- Act & Assert --
    // Should match case-sensitive 'api' subdomain
    XCTAssertTrue([options isNetworkDetailCaptureEnabledFor:@"https://api.example.com/users"]);
    XCTAssertTrue([options isNetworkDetailCaptureEnabledFor:@"https://api.example.com/api/data"]);
    
    // Should match case-insensitive 'analytics' subdomain
    XCTAssertTrue([options isNetworkDetailCaptureEnabledFor:@"https://analytics.myapp.com"]);
    XCTAssertTrue([options isNetworkDetailCaptureEnabledFor:@"https://ANALYTICS.example.com"]); // respects options:NSRegularExpressionCaseInsensitive

    // Should NOT match - wrong subdomain or case
    XCTAssertFalse([options isNetworkDetailCaptureEnabledFor:@"https://v2.example.com/api/users"]); // Wrong subdomain
    XCTAssertFalse([options isNetworkDetailCaptureEnabledFor:@"https://other.com/api/users"]); // Wrong domain
    XCTAssertFalse([options isNetworkDetailCaptureEnabledFor:@"https://API.example.com/users"]); // Case mismatch in subdomain
}

- (void)testIsNetworkDetailCaptureEnabled_withMixedPatterns_shouldSupportBoth
{
    // -- Arrange --
    NSError *error = nil;
    // Regex that requires version in path - won't match without /v[0-9]+/
    NSRegularExpression *regex =
        [NSRegularExpression regularExpressionWithPattern:@"^https://secure\\.api\\.com/v[0-9]+/.*"
                                                  options:0
                                                    error:&error];
    XCTAssertNil(error);

    // Mix substring pattern and regex pattern with distinct matching behavior
    NSDictionary *config = @{
        @"networkDetailAllowUrls": @[ @"/graphql", regex ],
        @"networkDetailDenyUrls": @[]
    };
    SentryReplayOptions *options = [[SentryReplayOptions alloc] initWithDictionary:config];

    // -- Act & Assert --
    // Substring matches
    XCTAssertTrue([options isNetworkDetailCaptureEnabledFor:@"https://api.example.com/graphql"]);
    XCTAssertTrue([options isNetworkDetailCaptureEnabledFor:@"https://myapp.com/api/graphql/query"]);

    // Regex matches
    XCTAssertTrue([options isNetworkDetailCaptureEnabledFor:@"https://secure.api.com/v1/users"]);
    XCTAssertTrue([options isNetworkDetailCaptureEnabledFor:@"https://secure.api.com/v2/data"]);
    XCTAssertFalse([options isNetworkDetailCaptureEnabledFor:@"https://secure.api.com/users"]);
    XCTAssertFalse([options isNetworkDetailCaptureEnabledFor:@"https://api.com/v1/users"]);
    XCTAssertFalse([options isNetworkDetailCaptureEnabledFor:@"https://other.example.com"]);
    XCTAssertFalse([options isNetworkDetailCaptureEnabledFor:@"https://api.other.com/rest"]);
}

- (void)testIsNetworkDetailCaptureEnabled_withDenyPatterns_shouldRespectDenyOverAllow
{
    // -- Arrange --
    NSError *error = nil;
    
    // Allow everything regex
    NSRegularExpression *allowAllRegex =
        [NSRegularExpression regularExpressionWithPattern:@".*"
                                                  options:0
                                                    error:&error];
    XCTAssertNil(error);
    
    NSRegularExpression *denyRegex =
        [NSRegularExpression regularExpressionWithPattern:@".*/(auth|login|password).*"
                                                  options:NSRegularExpressionCaseInsensitive
                                                    error:&error];
    XCTAssertNil(error);

    NSDictionary *config = @{
        @"networkDetailAllowUrls": @[ allowAllRegex ],
        @"networkDetailDenyUrls": @[ @"https://api.example.com/sensitive", denyRegex ]
    };
    SentryReplayOptions *options = [[SentryReplayOptions alloc] initWithDictionary:config];

    // -- Act & Assert --
    // Should deny these (substring match)
    XCTAssertFalse(
        [options isNetworkDetailCaptureEnabledFor:@"https://api.example.com/sensitive/data"]);

    // Should deny these (regex match)
    XCTAssertFalse(
        [options isNetworkDetailCaptureEnabledFor:@"https://api.example.com/auth/token"]);
    XCTAssertFalse(
        [options isNetworkDetailCaptureEnabledFor:@"https://api.example.com/user/login"]);
    XCTAssertFalse(
        [options isNetworkDetailCaptureEnabledFor:@"https://api.example.com/PASSWORD/reset"]);
}

@end
