@import XCTest;

#import "SentryJSONStreamWriter.h"

#include <float.h>
#include <math.h>

typedef struct {
    __unsafe_unretained NSMutableData *data;
    NSUInteger callCount;
    NSUInteger rejectAtCall;
} SentryJSONStreamTestOutput;

static bool
appendJSON(const char *const data, const size_t length, void *const userData)
{
    SentryJSONStreamTestOutput *output = userData;
    output->callCount++;
    if (output->rejectAtCall != 0 && output->callCount == output->rejectAtCall) {
        return false;
    }
    [output->data appendBytes:data length:length];
    return true;
}

static bool
serializeRepresentativeJSON(SentryJSONStreamWriter *const writer)
{
    return sentryJSONStreamWriter_beginObject(writer, NULL)
        && sentryJSONStreamWriter_addString(writer, "text", "quoted \" slash \\")
        && sentryJSONStreamWriter_beginArray(writer, "items")
        && sentryJSONStreamWriter_beginObject(writer, NULL)
        && sentryJSONStreamWriter_addDouble(writer, "number", 1.25)
        && sentryJSONStreamWriter_addBool(writer, "enabled", true)
        && sentryJSONStreamWriter_endContainer(writer)
        && sentryJSONStreamWriter_endContainer(writer)
        && sentryJSONStreamWriter_endContainer(writer) && sentryJSONStreamWriter_finish(writer);
}

@interface SentryJSONStreamWriterTests : XCTestCase
@end

@implementation SentryJSONStreamWriterTests

- (void)testRepresentativeSerialization
{
    NSMutableData *data = [NSMutableData data];
    SentryJSONStreamTestOutput output = { .data = data };
    SentryJSONStreamWriter writer;
    sentryJSONStreamWriter_init(&writer, appendJSON, &output);

    XCTAssertTrue(serializeRepresentativeJSON(&writer));
    NSString *expected = [@[
        @"{\"text\":\"quoted ", @"\\\"", @" slash ", @"\\\\",
        @"\",\"items\":[{\"number\":1.25,\"enabled\":true}]}"
    ] componentsJoinedByString:@""];
    XCTAssertEqualObjects(
        [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding], expected);
}

- (void)testEscapesStringsAndPropertyNamesLikeLegacySerializer
{
    NSMutableData *data = [NSMutableData data];
    SentryJSONStreamTestOutput output = { .data = data };
    SentryJSONStreamWriter writer;
    sentryJSONStreamWriter_init(&writer, appendJSON, &output);

    XCTAssertTrue(sentryJSONStreamWriter_beginObject(&writer, NULL));
    XCTAssertTrue(
        sentryJSONStreamWriter_addString(&writer, "quote\"slash\\", "\"\\\b\f\n\r\t utf8 😀"));
    XCTAssertTrue(sentryJSONStreamWriter_endContainer(&writer));
    XCTAssertTrue(sentryJSONStreamWriter_finish(&writer));

    XCTAssertEqualObjects([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding],
        @"{\"quote\\\"slash\\\\\":\"\\\"\\\\\\b\\f\\n\\r\\t utf8 😀\"}");
}

- (void)testRejectsUnsupportedControlCharacterAndRemainsFailed
{
    NSMutableData *data = [NSMutableData data];
    SentryJSONStreamTestOutput output = { .data = data };
    SentryJSONStreamWriter writer;
    sentryJSONStreamWriter_init(&writer, appendJSON, &output);
    const char invalid[] = { 'a', 1, 'b', 0 };

    XCTAssertTrue(sentryJSONStreamWriter_beginObject(&writer, NULL));
    XCTAssertFalse(sentryJSONStreamWriter_addString(&writer, "value", invalid));
    const NSUInteger callsAfterFailure = output.callCount;
    XCTAssertFalse(sentryJSONStreamWriter_addBool(&writer, "ignored", true));
    XCTAssertFalse(sentryJSONStreamWriter_endContainer(&writer));
    XCTAssertFalse(sentryJSONStreamWriter_finish(&writer));
    XCTAssertEqual(output.callCount, callsAfterFailure);
}

- (void)testFormatsFloatingPointValuesLikeLegacySerializer
{
    NSMutableData *data = [NSMutableData data];
    SentryJSONStreamTestOutput output = { .data = data };
    SentryJSONStreamWriter writer;
    sentryJSONStreamWriter_init(&writer, appendJSON, &output);

    XCTAssertTrue(sentryJSONStreamWriter_beginObject(&writer, NULL));
    XCTAssertTrue(sentryJSONStreamWriter_addDouble(&writer, "finite", 1.25));
    XCTAssertTrue(sentryJSONStreamWriter_addDouble(&writer, "nan", NAN));
    XCTAssertTrue(sentryJSONStreamWriter_addDouble(&writer, "positive", INFINITY));
    XCTAssertTrue(sentryJSONStreamWriter_addDouble(&writer, "negative", -INFINITY));
    XCTAssertTrue(sentryJSONStreamWriter_addDouble(&writer, "negativeZero", -0.0));
    XCTAssertTrue(sentryJSONStreamWriter_endContainer(&writer));
    XCTAssertTrue(sentryJSONStreamWriter_finish(&writer));

    XCTAssertEqualObjects([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding],
        @"{\"finite\":1.25,\"nan\":null,\"positive\":1e999,\"negative\":-1e999,\"negativeZero\":-"
        @"0}");
}

- (void)testFormatsFloatingPointBoundaryValuesLikeLegacySerializer
{
    NSMutableData *data = [NSMutableData data];
    SentryJSONStreamTestOutput output = { .data = data };
    SentryJSONStreamWriter writer;
    sentryJSONStreamWriter_init(&writer, appendJSON, &output);

    XCTAssertTrue(sentryJSONStreamWriter_beginArray(&writer, NULL));
    XCTAssertTrue(sentryJSONStreamWriter_addDouble(&writer, NULL, 0.0));
    XCTAssertTrue(sentryJSONStreamWriter_addDouble(&writer, NULL, DBL_TRUE_MIN));
    XCTAssertTrue(sentryJSONStreamWriter_addDouble(&writer, NULL, DBL_MIN));
    XCTAssertTrue(sentryJSONStreamWriter_addDouble(&writer, NULL, DBL_MAX));
    XCTAssertTrue(sentryJSONStreamWriter_addDouble(&writer, NULL, 0.0001));
    XCTAssertTrue(sentryJSONStreamWriter_addDouble(&writer, NULL, 0.00001));
    XCTAssertTrue(sentryJSONStreamWriter_addDouble(&writer, NULL, 999999.0));
    XCTAssertTrue(sentryJSONStreamWriter_addDouble(&writer, NULL, 1000000.0));
    XCTAssertTrue(sentryJSONStreamWriter_addDouble(&writer, NULL, 1.234567));
    XCTAssertTrue(sentryJSONStreamWriter_endContainer(&writer));
    XCTAssertTrue(sentryJSONStreamWriter_finish(&writer));

    XCTAssertEqualObjects([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding],
        @"[0,4.94066e-324,2.22507e-308,1.79769e+308,0.0001,1e-05,999999,1e+06,1.23457]");
}

- (void)testSerializesEmptyAndNestedContainers
{
    NSMutableData *data = [NSMutableData data];
    SentryJSONStreamTestOutput output = { .data = data };
    SentryJSONStreamWriter writer;
    sentryJSONStreamWriter_init(&writer, appendJSON, &output);

    XCTAssertTrue(sentryJSONStreamWriter_beginObject(&writer, NULL));
    XCTAssertTrue(sentryJSONStreamWriter_beginArray(&writer, "emptyArray"));
    XCTAssertTrue(sentryJSONStreamWriter_endContainer(&writer));
    XCTAssertTrue(sentryJSONStreamWriter_beginObject(&writer, "emptyObject"));
    XCTAssertTrue(sentryJSONStreamWriter_endContainer(&writer));
    XCTAssertTrue(sentryJSONStreamWriter_beginArray(&writer, "nested"));
    XCTAssertTrue(sentryJSONStreamWriter_beginArray(&writer, NULL));
    XCTAssertTrue(sentryJSONStreamWriter_addBool(&writer, NULL, false));
    XCTAssertTrue(sentryJSONStreamWriter_endContainer(&writer));
    XCTAssertTrue(sentryJSONStreamWriter_endContainer(&writer));
    XCTAssertTrue(sentryJSONStreamWriter_endContainer(&writer));
    XCTAssertTrue(sentryJSONStreamWriter_finish(&writer));

    XCTAssertEqualObjects([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding],
        @"{\"emptyArray\":[],\"emptyObject\":{},\"nested\":[[false]]}");
}

- (void)testPropagatesFailureFromEveryOutputWrite
{
    NSMutableData *baselineData = [NSMutableData data];
    SentryJSONStreamTestOutput baselineOutput = { .data = baselineData };
    SentryJSONStreamWriter baselineWriter;
    sentryJSONStreamWriter_init(&baselineWriter, appendJSON, &baselineOutput);
    XCTAssertTrue(serializeRepresentativeJSON(&baselineWriter));
    XCTAssertGreaterThan(baselineOutput.callCount, 0U);

    for (NSUInteger rejectAtCall = 1; rejectAtCall <= baselineOutput.callCount; rejectAtCall++) {
        NSMutableData *data = [NSMutableData data];
        SentryJSONStreamTestOutput output = {
            .data = data,
            .rejectAtCall = rejectAtCall,
        };
        SentryJSONStreamWriter writer;
        sentryJSONStreamWriter_init(&writer, appendJSON, &output);

        XCTAssertFalse(serializeRepresentativeJSON(&writer), @"write %lu must propagate failure",
            (unsigned long)rejectAtCall);
        XCTAssertEqual(output.callCount, rejectAtCall);
        XCTAssertFalse(sentryJSONStreamWriter_addBool(&writer, NULL, true));
        XCTAssertEqual(output.callCount, rejectAtCall);
    }
}

- (void)testRejectsInvalidStructure
{
    NSMutableData *data = [NSMutableData data];
    SentryJSONStreamTestOutput output = { .data = data };
    SentryJSONStreamWriter writer;
    sentryJSONStreamWriter_init(&writer, appendJSON, &output);

    XCTAssertFalse(sentryJSONStreamWriter_endContainer(&writer));
    XCTAssertFalse(sentryJSONStreamWriter_finish(&writer));

    sentryJSONStreamWriter_init(&writer, appendJSON, &output);
    XCTAssertTrue(sentryJSONStreamWriter_beginObject(&writer, NULL));
    XCTAssertFalse(sentryJSONStreamWriter_addBool(&writer, NULL, true));

    sentryJSONStreamWriter_init(&writer, appendJSON, &output);
    XCTAssertTrue(sentryJSONStreamWriter_beginArray(&writer, NULL));
    XCTAssertFalse(sentryJSONStreamWriter_finish(&writer));
}

- (void)testRejectsContainerBeyondFixedBudget
{
    NSMutableData *data = [NSMutableData data];
    SentryJSONStreamTestOutput output = { .data = data };
    SentryJSONStreamWriter writer;
    sentryJSONStreamWriter_init(&writer, appendJSON, &output);

    for (NSUInteger index = 0; index < SENTRY_JSON_STREAM_MAX_CONTAINERS; index++) {
        XCTAssertTrue(sentryJSONStreamWriter_beginArray(&writer, NULL));
    }
    XCTAssertFalse(sentryJSONStreamWriter_beginArray(&writer, NULL));
    XCTAssertFalse(sentryJSONStreamWriter_finish(&writer));
}

@end
