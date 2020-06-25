#import "SentryOptions.h"
#import "SentryError.h"
#import "SentrySDK.h"
#import "SentryTests-Swift.h"
#import <XCTest/XCTest.h>

@interface SentryOptionsTest : XCTestCase

@end

@implementation SentryOptionsTest

- (void)testEmptyDsn
{
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{} didFailWithError:&error];

    [self assertDisabled:options andError:error];
}

- (void)testInvalidDsnBoolean
{
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{ @"dsn" : @YES }
                                                didFailWithError:&error];

    [self assertDisabled:options andError:error];
}

- (void)assertDisabled:(SentryOptions *)options andError:(NSError *)error
{
    XCTAssertNil(options.parsedDsn);
    XCTAssertEqual(@NO, options.enabled);
    XCTAssertEqual(@NO, options.debug);
    XCTAssertNil(error);
}

- (void)testInvalidDsn
{
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{ @"dsn" : @"https://sentry.io" }
                                                didFailWithError:&error];
    XCTAssertEqual(kSentryErrorInvalidDsnError, error.code);
    XCTAssertNil(options);
}

- (void)testRelease
{
    SentryOptions *options = [self getValidOptions:@{ @"release" : @"abc" }];
    XCTAssertEqualObjects(options.releaseName, @"abc");
}

- (void)testSetEmptyRelease
{
    SentryOptions *options = [self getValidOptions:@{ @"release" : @"" }];
    XCTAssertEqualObjects(options.releaseName, @"");
}

- (void)testSetReleaseToNonString
{
    SentryOptions *options = [self getValidOptions:@{ @"release" : @2 }];
    XCTAssertEqualObjects(options.releaseName, [self buildDefaultReleaseName]);
}

- (void)testNoReleaseSetUsesDefault
{
    SentryOptions *options = [self getValidOptions:@{}];
    XCTAssertEqualObjects(options.releaseName, [self buildDefaultReleaseName]);
}

- (NSString *)buildDefaultReleaseName
{
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    return [NSString stringWithFormat:@"%@@%@+%@", infoDict[@"CFBundleIdentifier"],
                     infoDict[@"CFBundleShortVersionString"], infoDict[@"CFBundleVersion"]];
}

- (void)testEnvironment
{
    SentryOptions *options = [self getValidOptions:@{}];
    XCTAssertNil(options.environment);

    options = [self getValidOptions:@{ @"environment" : @"xxx" }];
    XCTAssertEqualObjects(options.environment, @"xxx");
}

- (void)testDist
{
    SentryOptions *options = [self getValidOptions:@{}];
    XCTAssertNil(options.dist);

    options = [self getValidOptions:@{ @"dist" : @"hhh" }];
    XCTAssertEqualObjects(options.dist, @"hhh");
}

- (void)testValidDebug
{
    [self testDebugWith:@YES expected:@YES expectedLogLevel:kSentryLogLevelDebug];
    [self testDebugWith:@"YES" expected:@YES expectedLogLevel:kSentryLogLevelDebug];
}

- (void)testInvalidDebug
{
    [self testDebugWith:@"Invalid" expected:@NO expectedLogLevel:kSentryLogLevelError];
    [self testDebugWith:@NO expected:@NO expectedLogLevel:kSentryLogLevelError];
}

- (void)testDebugWith:(NSObject *)debugValue
             expected:(NSNumber *)expectedDebugValue
     expectedLogLevel:(SentryLogLevel)expectedLogLevel
{
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{ @"debug" : debugValue }
                                                didFailWithError:&error];

    XCTAssertNil(error);
    XCTAssertEqual(expectedDebugValue, options.debug);
    XCTAssertEqual(expectedLogLevel, SentrySDK.logLevel);
}

- (void)testDebugWithVerbose
{
    NSError *error = nil;
    SentryOptions *options =
        [[SentryOptions alloc] initWithDict:@{ @"debug" : @YES, @"logLevel" : @"verbose" }
                           didFailWithError:&error];

    XCTAssertNil(error);
    XCTAssertEqual(@YES, options.debug);
    XCTAssertEqual(kSentryLogLevelVerbose, SentrySDK.logLevel);
}

- (void)testValidEnabled
{
    [self testEnabledWith:@YES expected:@YES];
    [self testEnabledWith:@"YES" expected:@YES];
}

- (void)testInvalidEnabled
{
    [self testEnabledWith:@"Invalid" expected:@NO];
    [self testEnabledWith:@NO expected:@NO];
}

- (void)testEnabledWith:(NSObject *)enabledValue expected:(NSNumber *)expectedValue
{
    SentryOptions *options = [self getValidOptions:@{ @"enabled" : enabledValue }];

    XCTAssertEqual(expectedValue, options.enabled);
}

- (void)testMaxBreadCrumbs
{
    NSNumber *maxBreadCrumbs = @20;

    SentryOptions *options = [self getValidOptions:@{ @"maxBreadcrumbs" : maxBreadCrumbs }];

    XCTAssertEqual([maxBreadCrumbs unsignedIntValue], options.maxBreadcrumbs);
}

- (void)testDefaultMaxBreadCrumbs
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertEqual([@100 unsignedIntValue], options.maxBreadcrumbs);
}

- (void)testBeforeSend
{
    SentryEvent * (^callback)(SentryEvent *event) = ^(SentryEvent *event) { return event; };
    SentryOptions *options = [self getValidOptions:@{ @"beforeSend" : callback }];

    XCTAssertEqual(callback, options.beforeSend);
}

- (void)testDefaultBeforeSend
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertNil(options.beforeSend);
}

- (void)testBeforeBreadcrumb
{
    SentryBreadcrumb * (^callback)(SentryBreadcrumb *event)
        = ^(SentryBreadcrumb *breadcrumb) { return breadcrumb; };
    SentryOptions *options = [self getValidOptions:@{ @"beforeBreadcrumb" : callback }];

    XCTAssertEqual(callback, options.beforeBreadcrumb);
}

- (void)testDefaultBeforeBreadcrumb
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertNil(options.beforeBreadcrumb);
}

- (void)testIntegrations
{
    NSArray<NSString *> *integrations = @[ @"integration1", @"integration2" ];
    SentryOptions *options = [self getValidOptions:@{ @"integrations" : integrations }];

    XCTAssertEqual(integrations, options.integrations);
}

- (void)testDefaultIntegrations
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertTrue([[SentryOptions defaultIntegrations] isEqualToArray:options.integrations],
        @"Default integrations are not set correctly");
}

- (void)testSampleRateLowerBound
{
    NSNumber *sampleRateLowerBound = @0;
    SentryOptions *options = [self getValidOptions:@{ @"sampleRate" : sampleRateLowerBound }];
    XCTAssertEqual(sampleRateLowerBound, options.sampleRate);

    NSNumber *sampleRateTooLow = @-0.01;
    options = [self getValidOptions:@{ @"sampleRate" : sampleRateTooLow }];
    XCTAssertEqual(@1, options.sampleRate);
}

- (void)testSampleRateUpperBound
{
    NSNumber *sampleRateUpperBound = @1;
    SentryOptions *options = [self getValidOptions:@{ @"sampleRate" : sampleRateUpperBound }];
    XCTAssertEqual(sampleRateUpperBound, options.sampleRate);

    NSNumber *sampleRateTooHigh = @1.01;
    options = [self getValidOptions:@{ @"sampleRate" : sampleRateTooHigh }];
    XCTAssertEqual(@1, options.sampleRate);
}

- (void)testSampleRateNotSet
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertEqual(@1, options.sampleRate);
}

- (void)testEnableAutoSessionTracking
{
    SentryOptions *options = [self getValidOptions:@{ @"enableAutoSessionTracking" : @YES }];

    XCTAssertEqual(@YES, options.enableAutoSessionTracking);
}

- (void)testDefaultEnableAutoSessionTracking
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertEqual(@NO, options.enableAutoSessionTracking);
}

- (void)testSessionTrackingIntervalMillis
{
    NSNumber *sessionTracking = @2000;
    SentryOptions *options =
        [self getValidOptions:@{ @"sessionTrackingIntervalMillis" : sessionTracking }];

    XCTAssertEqual([sessionTracking unsignedIntValue], options.sessionTrackingIntervalMillis);
}

- (void)testDefaultSessionTrackingIntervalMillis
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertEqual([@30000 unsignedIntValue], options.sessionTrackingIntervalMillis);
}

- (void)testAttachStackTraceDisabledPerDefault
{
    SentryOptions *options = [self getValidOptions:@{}];
    XCTAssertEqual(@NO, options.attachStacktrace);
}

- (void)testAttachStackTraceEnabled
{
    SentryOptions *options = [self getValidOptions:@{ @"attachStacktrace" : @YES }];
    XCTAssertEqual(@YES, options.attachStacktrace);
}

- (void)testInvalidAttachStackTrace
{
    SentryOptions *options = [self getValidOptions:@{ @"attachStacktrace" : @"Invalid" }];
    XCTAssertEqual(@NO, options.attachStacktrace);
}

- (void)testEmptyConstructorSetsDefaultValues
{
    SentryOptions *options = [[SentryOptions alloc] init];

    XCTAssertEqual(@NO, options.enabled);
    XCTAssertEqual(@NO, options.debug);
    XCTAssertEqual(kSentryLogLevelError, options.logLevel);
    XCTAssertNil(options.parsedDsn);
    XCTAssertEqual(defaultMaxBreadcrumbs, options.maxBreadcrumbs);
    XCTAssertTrue([[SentryOptions defaultIntegrations] isEqualToArray:options.integrations],
        @"Default integrations are not set correctly");
    XCTAssertEqual(@1, options.sampleRate);
    XCTAssertEqual(@NO, options.enableAutoSessionTracking);
    XCTAssertEqual([@30000 unsignedIntValue], options.sessionTrackingIntervalMillis);
    XCTAssertEqual(@NO, options.attachStacktrace);
}

- (void)testSetValidDsn
{
    NSString *dsnAsString = @"https://username:password@sentry.io/1";
    SentryOptions *options = [[SentryOptions alloc] init];
    options.dsn = dsnAsString;

    SentryDsn *dsn = [[SentryDsn alloc] initWithString:dsnAsString didFailWithError:nil];

    XCTAssertEqual(dsnAsString, options.dsn);
    XCTAssertTrue([dsn.url.absoluteString isEqualToString:options.parsedDsn.url.absoluteString]);
    XCTAssertEqual(@YES, options.enabled);
}

- (void)testSetNilDsn
{
    SentryOptions *options = [[SentryOptions alloc] init];

    [options setDsn:nil];
    XCTAssertEqual(@NO, options.enabled);
    XCTAssertNil(options.dsn);
    XCTAssertNil(options.parsedDsn);
}

- (void)testSetInvalidValidDsn
{
    SentryOptions *options = [[SentryOptions alloc] init];

    [options setDsn:@"https://username:passwordsentry.io/1"];
    XCTAssertNil(options.dsn);
    XCTAssertNil(options.parsedDsn);
    XCTAssertEqual(@NO, options.enabled);
}

- (SentryOptions *)getValidOptions:(NSDictionary<NSString *, id> *)dict
{
    NSError *error = nil;

    NSMutableDictionary<NSString *, id> *options = [[NSMutableDictionary alloc] init];
    options[@"dsn"] = @"https://username:password@sentry.io/1";

    [options addEntriesFromDictionary:dict];

    SentryOptions *sentryOptions = [[SentryOptions alloc] initWithDict:options
                                                      didFailWithError:&error];
    XCTAssertNil(error);
    return sentryOptions;
}

@end
