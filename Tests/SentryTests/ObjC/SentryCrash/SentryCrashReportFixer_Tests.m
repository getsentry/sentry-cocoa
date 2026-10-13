#if !SDK_V10
@import SentryTestUtilsObjC;
#    import <XCTest/XCTest.h>

@interface SentryCrashReportFixer_Tests : XCTestCase

@end

@implementation SentryCrashReportFixer_Tests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each
    // test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of
    // each test method in the class.
    [super tearDown];
}

- (void)testLoadCrash
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *rawPath = [bundle pathForResource:@"Resources/raw" ofType:@"json"];
    NSData *rawData = [NSData dataWithContentsOfFile:rawPath];
    char *fixedBytes = sentrycrashcrf_fixupCrashReport(rawData.bytes);
    //    NSLog(@"%@", [[NSString alloc] initWithData:[NSData
    //    dataWithBytes:fixedBytes length:strlen(fixedBytes)]
    //    encoding:NSUTF8StringEncoding]);
    NSData *fixedData = [NSData dataWithBytesNoCopy:fixedBytes length:strlen(fixedBytes)];
    NSError *error = nil;
    id fixedObjects = [NSJSONSerialization JSONObjectWithData:fixedData options:0 error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(fixedObjects);

    NSString *processedPath = [bundle pathForResource:@"Resources/processed" ofType:@"json"];
    NSData *processedData = [NSData dataWithContentsOfFile:processedPath];
    id processedObjects = [NSJSONSerialization JSONObjectWithData:processedData
                                                          options:0
                                                            error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(processedObjects);

    XCTAssertEqualObjects(fixedObjects, processedObjects);
}

- (void)testFixupCrashReport_whenReasonExceedsLegacyBuffer_shouldKeepFullString
{
    // -- Arrange --
    // The previous 150KB scratch buffer only had 112.5KB for values. AutoLayout
    // NSException reasons are stored twice and can be ~900KB each.
    NSString *reason = [@"" stringByPaddingToLength:200000 withString:@"a" startingAtIndex:0];
    NSDictionary *report = @{
        @"crash" : @ {
            @"error" : @ {
                @"type" : @"nsexception",
                @"reason" : reason,
                @"nsexception" : @ { @"name" : @"NSException", @"reason" : reason }
            }
        }
    };
    NSError *encodeError = nil;
    NSData *reportData = [NSJSONSerialization dataWithJSONObject:report
                                                         options:0
                                                           error:&encodeError];
    XCTAssertNil(encodeError);
    NSString *reportJSON = [[NSString alloc] initWithData:reportData encoding:NSUTF8StringEncoding];
    XCTAssertNotNil(reportJSON);

    // -- Act --
    char *fixedBytes = sentrycrashcrf_fixupCrashReport(reportJSON.UTF8String);

    // -- Assert --
    XCTAssertTrue(fixedBytes != NULL);
    if (fixedBytes == NULL) {
        return;
    }
    NSData *fixedData = [NSData dataWithBytesNoCopy:fixedBytes length:strlen(fixedBytes)];
    NSError *decodeError = nil;
    NSDictionary *fixedObjects = [NSJSONSerialization JSONObjectWithData:fixedData
                                                                 options:0
                                                                   error:&decodeError];
    XCTAssertNil(decodeError);
    XCTAssertEqualObjects(fixedObjects[@"crash"][@"error"][@"reason"], reason);
    XCTAssertEqualObjects(fixedObjects[@"crash"][@"error"][@"nsexception"][@"reason"], reason);
}

@end

#endif // !SDK_V10
