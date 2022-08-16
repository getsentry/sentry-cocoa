#import "SentryClient.h"
#import "SentryDefines.h"
#import "SentryHub.h"
#import "SentryOptions.h"
#import "SentrySDK+Private.h"
#import "SentrySDK.h"
#import <XCTest/XCTest.h>

@interface SentryDeprecatedSDKAPITests : XCTestCase

@end

/**
 * Because @c SentrySDKTests.testStartWithConfigureOptions is Swift source, the new
 * deprecation warning on @c diagnosticLevel can't be ignored and becomes an error that breaks the
 * build. So, move the assertion to this Objective-C test case that is able to ignore the warning.
 */
@implementation SentryDeprecatedSDKAPITests

- (void)testStartWithCOnfigureOptionsAndDiagnoticLevel
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [SentrySDK startWithConfigureOptions:^(
        SentryOptions *_Nonnull options) { options.diagnosticLevel = kSentryLevelDebug; }];

    XCTAssertEqual([SentrySDK.currentHub getClient].options.diagnosticLevel, kSentryLevelDebug);
#pragma clang diagnostic pop
}

@end
