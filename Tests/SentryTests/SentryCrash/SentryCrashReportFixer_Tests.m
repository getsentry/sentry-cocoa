#import "SentryCrashReportFixer.h"
#import <XCTest/XCTest.h>

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

@end
