#import "SentryProfileTimeseries.h"
#import "SentryEvent+Private.h"
#import "SentryInternalDefines.h"
#import "SentryLog.h"
#import "SentryTransaction.h"

/**
 * Print a debug log to help diagnose slicing errors.
 * @param start @c YES if this is an attempt to find the start of the sliced data based on the
 * transaction start; @c NO if it's trying to find the end of the sliced data based on the
 * transaction's end, to accurately describe what's happening in the log statement.
 */
void
logSlicingFailureWithArray(
    NSArray<SentrySample *> *array, SentryTransaction *transaction, BOOL start)
{
    if (!SENTRY_CASSERT(array.count > 0, @"Should not have attempted to slice an empty array.")) {
        return;
    }

    if (![SentryLog willLogAtLevel:kSentryLevelDebug]) {
        return;
    }

    const auto firstSampleAbsoluteTime = array.firstObject.absoluteTimestamp;
    const auto lastSampleAbsoluteTime = array.lastObject.absoluteTimestamp;
    const auto firstSampleRelativeToTransactionStart
        = firstSampleAbsoluteTime - transaction.startSystemTime;
    const auto lastSampleRelativeToTransactionStart
        = lastSampleAbsoluteTime - transaction.startSystemTime;
    SENTRY_LOG_DEBUG(@"[slice %@] Could not find any%@ sample taken during the transaction "
                     @"(first sample taken at: %llu; last: %llu; transaction start: %llu; end: "
                     @"%llu; first sample relative to transaction start: %lld; last: %lld).",
        start ? @"start" : @"end", start ? @"" : @" other", firstSampleAbsoluteTime,
        lastSampleAbsoluteTime, transaction.startSystemTime, transaction.endSystemTime,
        firstSampleRelativeToTransactionStart, lastSampleRelativeToTransactionStart);
}

NSArray<SentrySample *> *_Nullable slicedProfileSamples(
    NSArray<SentrySample *> *samples, SentryTransaction *transaction)
{
    NSArray<SentrySample *> *samplesCopy = [samples copy];

    if (samplesCopy.count == 0) {
        return nil;
    }

    const auto firstIndex = [samplesCopy indexOfObjectPassingTest:^BOOL(
        SentrySample *_Nonnull sample, NSUInteger idx, BOOL *_Nonnull stop) {
        *stop = sample.absoluteTimestamp >= transaction.startSystemTime;
        return *stop;
    }];

    if (firstIndex == NSNotFound) {
        logSlicingFailureWithArray(samplesCopy, transaction, /*start*/ YES);
        return nil;
    } else {
        SENTRY_LOG_DEBUG(@"Found first slice sample at index %lu", firstIndex);
    }

    const auto lastIndex =
        [samplesCopy indexOfObjectWithOptions:NSEnumerationReverse
                                  passingTest:^BOOL(SentrySample *_Nonnull sample, NSUInteger idx,
                                      BOOL *_Nonnull stop) {
                                      *stop = sample.absoluteTimestamp <= transaction.endSystemTime;
                                      return *stop;
                                  }];

    if (lastIndex == NSNotFound) {
        logSlicingFailureWithArray(samplesCopy, transaction, /*start*/ NO);
        return nil;
    } else {
        SENTRY_LOG_DEBUG(@"Found last slice sample at index %lu", lastIndex);
    }

    const auto range = NSMakeRange(firstIndex, (lastIndex - firstIndex) + 1);
    const auto indices = [NSIndexSet indexSetWithIndexesInRange:range];
    return [samplesCopy objectsAtIndexes:indices];
}

@implementation SentrySample
@end
