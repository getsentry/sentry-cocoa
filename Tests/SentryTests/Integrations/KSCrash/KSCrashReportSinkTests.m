#import "KSCrashReportSink.h"
#import "SentrySwift.h"
#import <XCTest/XCTest.h>
@import KSCrashRecording;
@import Sentry;

@interface KSCrashReportSinkTests : XCTestCase
@end

@implementation KSCrashReportSinkTests

- (void)test_filterReports_emptyArray_callsCompletionWithNoError
{
    SentryInAppLogic *logic = [[SentryInAppLogic alloc] initWithInAppIncludes:@[]];
    KSCrashReportSink *sink = [[KSCrashReportSink alloc] initWithInAppLogic:logic];
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];
    [sink filterReports:@[]
           onCompletion:^(NSArray<id<KSCrashReport>> *_Nullable __unused filteredReports,
               NSError *_Nullable error) {
               XCTAssertNil(error);
               [expectation fulfill];
           }];
    [self waitForExpectations:@[ expectation ] timeout:2.0];
}

- (void)test_filterReports_nonDictionaryReport_isSkipped
{
    SentryInAppLogic *logic = [[SentryInAppLogic alloc] initWithInAppIncludes:@[]];
    KSCrashReportSink *sink = [[KSCrashReportSink alloc] initWithInAppLogic:logic];
    KSCrashReportString *stringReport = [KSCrashReportString reportWithValue:@"{}"];
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];
    [sink filterReports:@[ stringReport ]
           onCompletion:^(NSArray<id<KSCrashReport>> *_Nullable __unused filteredReports,
               NSError *_Nullable error) {
               XCTAssertNil(error);
               [expectation fulfill];
           }];
    [self waitForExpectations:@[ expectation ] timeout:2.0];
}

- (void)test_filterReports_emptyDictionaryReport_noClientSet_doesNotCrash
{
    // With no Sentry client configured, the sink should handle an empty report
    // gracefully (the converter will return nil) and still call completion.
    SentryInAppLogic *logic = [[SentryInAppLogic alloc] initWithInAppIncludes:@[]];
    KSCrashReportSink *sink = [[KSCrashReportSink alloc] initWithInAppLogic:logic];
    KSCrashReportDictionary *report = [KSCrashReportDictionary reportWithValue:@{ }];
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];
    [sink filterReports:@[ report ]
           onCompletion:^(NSArray<id<KSCrashReport>> *_Nullable __unused filteredReports,
               NSError *_Nullable error) {
               XCTAssertNil(error);
               [expectation fulfill];
           }];
    [self waitForExpectations:@[ expectation ] timeout:2.0];
}

@end
