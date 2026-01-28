#import "SentryFileIOTrackerHelper.h"
#import "SentryClient+Private.h"
#import "SentryFrame.h"
#import "SentryHub+Private.h"
#import "SentryInternalDefines.h"
#import "SentryLogC.h"
#import "SentrySDK+Private.h"
#import "SentryScope+Private.h"
#import "SentrySpanDataKey.h"
#import "SentrySpanInternal.h"
#import "SentrySpanOperation.h"
#import "SentrySpanProtocol.h"
#import "SentryStacktrace.h"
#import "SentrySwift.h"
#import "SentryThread.h"
#import "SentryTracer.h"

@interface SentryFileIOTrackerHelper ()

@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, strong) NSMutableSet<NSData *> *processingData;
@property (nonatomic, copy) SentryStacktrace *_Nullable (^stacktraceRetrieval)(void);

@end

@implementation SentryFileIOTrackerHelper

NSString *const SENTRY_TRACKING_COUNTER_KEY = @"SENTRY_TRACKING_COUNTER_KEY";

- (instancetype)initWithThreadInspector:(SentryStacktrace *_Nullable (^)(void))stacktraceRetrieval
{
    if (self = [super init]) {
        self.stacktraceRetrieval = stacktraceRetrieval;
    }
    return self;
}

- (void)enable
{
    @synchronized(self) {
        self.isEnabled = YES;
    }
}

- (void)disable
{
    @synchronized(self) {
        self.isEnabled = NO;
    }
}

- (BOOL)measureNSData:(NSData *)data
             writeToFile:(NSString *)path
              atomically:(BOOL)useAuxiliaryFile
                  origin:(NSString *)origin
    processDirectoryPath:(NSString *)processDirectoryPath
                  method:(BOOL (^)(NSString *, BOOL))method
{
    id<SentrySpan> span = [self startTrackingWritingNSData:data
                                                  filePath:path
                                                    origin:origin
                                      processDirectoryPath:processDirectoryPath];

    BOOL result = method(path, useAuxiliaryFile);

    if (span != nil) {
        [self finishTrackingNSData:@(data.length) span:span];
    }
    return result;
}

- (BOOL)measureNSData:(NSData *)data
             writeToFile:(NSString *)path
                 options:(NSDataWritingOptions)writeOptionsMask
                  origin:(NSString *)origin
    processDirectoryPath:(NSString *)processDirectoryPath
                   error:(NSError **)error
                  method:(BOOL (^)(NSString *, NSDataWritingOptions, NSError **))method
{
    id<SentrySpan> span = [self startTrackingWritingNSData:data
                                                  filePath:path
                                                    origin:origin
                                      processDirectoryPath:processDirectoryPath];

    BOOL result = method(path, writeOptionsMask, error);

    if (span != nil) {
        [self finishTrackingNSData:@(data.length) span:span];
    }

    return result;
}

- (void)measureNSDataFromFile:(NSString *)path
                       origin:(NSString *)origin
         processDirectoryPath:(NSString *)processDirectoryPath
                       method:(NSNumber * (^)(void))method
{
    id<SentrySpan> span = [self startTrackingReadingFilePath:path
                                                      origin:origin
                                                   operation:SentrySpanOperationFileRead
                                        processDirectoryPath:processDirectoryPath];

    NSNumber *length = method();

    if (span != nil) {
        [self finishTrackingNSData:length span:span];
    }

    [self endTrackingFile];
}

- (void)measureNSDataFromURL:(NSURL *)url
                      origin:(NSString *)origin
        processDirectoryPath:(NSString *)processDirectoryPath
                      method:(NSNumber * (^)(void))method
{

    // We dont track reads from a url that is not a file url
    // because these reads are handled by NSURLSession and
    // SentryNetworkTracker will create spans in these cases.
    if (![url.scheme isEqualToString:NSURLFileScheme]) {
        method();
        return;
    }

    id<SentrySpan> span = [self startTrackingReadingFilePath:url.path
                                                      origin:origin
                                                   operation:SentrySpanOperationFileRead
                                        processDirectoryPath:processDirectoryPath];

    NSNumber *length = method();

    if (span != nil) {
        [self finishTrackingNSData:length span:span];
    }

    [self endTrackingFile];
    return;
}

- (BOOL)measureNSFileManagerCreateFileAtPath:(NSString *)path
                                        data:(NSData *)data
                                  attributes:(NSDictionary<NSFileAttributeKey, id> *)attributes
                                      origin:(NSString *)origin
                        processDirectoryPath:(NSString *)processDirectoryPath
                                      method:
                                          (BOOL (^)(NSString *_Nonnull, NSData *_Nonnull,
                                              NSDictionary<NSFileAttributeKey, id> *_Nonnull))method
{
    id<SentrySpan> span = [self startTrackingWritingNSData:data
                                                  filePath:path
                                                    origin:origin
                                      processDirectoryPath:processDirectoryPath];

    BOOL result = method(path, data, attributes);

    if (span != nil) {
        [self finishTrackingNSData:@(data.length) span:span];
    }
    return result;
}

- (nullable id<SentrySpan>)spanForPath:(NSString *)path
                                origin:(NSString *)origin
                             operation:(NSString *)operation
                  processDirectoryPath:(NSString *)processDirectoryPath
{
    return [self spanForPath:path
                      origin:origin
                   operation:operation
        processDirectoryPath:processDirectoryPath
                        size:0];
}

- (nullable id<SentrySpan>)spanForPath:(NSString *)path
                                origin:(NSString *)origin
                             operation:(NSString *)operation
                  processDirectoryPath:(NSString *)processDirectoryPath
                                  size:(NSUInteger)size
{
    @synchronized(self) {
        if (!self.isEnabled) {
            return nil;
        }
    }

    if ([self ignoreFile:path]) {
        return nil;
    }

    NSString *spanDescription = [self transactionDescriptionForFile:path fileSize:size];
    id<SentrySpan> _Nullable currentSpan = [SentrySDKInternal.currentHub.scope span];
    if (currentSpan == NULL) {
        SENTRY_LOG_DEBUG(@"No transaction bound to scope. Won't track file IO operation.");
        return nil;
    }

    id<SentrySpan> _Nullable ioSpan = [currentSpan startChildWithOperation:operation
                                                               description:spanDescription];
    if (ioSpan == nil) {
        SENTRY_LOG_DEBUG(@"No transaction bound to scope. Won't track file IO operation.");
        return nil;
    }

    ioSpan.origin = origin;
    [ioSpan setDataValue:path forKey:SentrySpanDataKeyFilePath];
    if (size > 0) {
        [ioSpan setDataValue:[NSNumber numberWithUnsignedInteger:size]
                      forKey:SentrySpanDataKeyFileSize];
    }

    SENTRY_LOG_DEBUG(
        @"Automatically started a new span with description: %@, operation: %@, origin: %@",
        ioSpan.description, operation, origin);

    [self mainThreadExtraInfo:ioSpan processDirectoryPath:processDirectoryPath];

    return ioSpan;
}

- (void)mainThreadExtraInfo:(id<SentrySpan>)span
       processDirectoryPath:(NSString *)processDirectoryPath
{
    BOOL isMainThread = [NSThread isMainThread];

    [span setDataValue:@(isMainThread) forKey:SPAN_DATA_BLOCKED_MAIN_THREAD];

    if (!isMainThread) {
        return;
    }

    SentryStacktrace *stackTrace = self.stacktraceRetrieval();

    NSArray *frames = [stackTrace.frames
        filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(SentryFrame *frame,
                                        NSDictionary<NSString *, id> *bindings) {
            return [frame.package hasPrefix:processDirectoryPath];
        }]];

    if (frames.count <= 1) {
        // This means the call was made only by system APIs
        // and only the 'main' frame remains in the stack
        // therefore, there is nothing to do about it
        // and we should not report it as an issue.
        [span setDataValue:@(NO) forKey:SPAN_DATA_BLOCKED_MAIN_THREAD];
    } else {
        [((SentrySpanInternal *)span) setFrames:frames];
    }
}

- (nullable id<SentrySpan>)startTrackingWritingNSData:(NSData *)data
                                             filePath:(NSString *)path
                                               origin:(NSString *)origin
                                 processDirectoryPath:(NSString *)processDirectoryPath
{
    return [self spanForPath:path
                      origin:origin
                   operation:SentrySpanOperationFileWrite
        processDirectoryPath:processDirectoryPath
                        size:data.length];
}

- (nullable id<SentrySpan>)startTrackingReadingFilePath:(NSString *)path
                                                 origin:(NSString *)origin
                                              operation:(NSString *)operation
                                   processDirectoryPath:(NSString *)processDirectoryPath
{
    // Some iOS versions nest constructors calls. This counter help us avoid create more than one
    // span for the same operation.
    NSNumber *count =
        [[NSThread currentThread].threadDictionary objectForKey:SENTRY_TRACKING_COUNTER_KEY];
    [[NSThread currentThread].threadDictionary setObject:[NSNumber numberWithInt:count.intValue + 1]
                                                  forKey:SENTRY_TRACKING_COUNTER_KEY];

    if (count)
        return nil;

    return [self spanForPath:path
                      origin:origin
                   operation:operation
        processDirectoryPath:processDirectoryPath
                        size:0];
}

- (void)endTrackingFile
{
    NSNumber *count =
        [[NSThread currentThread].threadDictionary objectForKey:SENTRY_TRACKING_COUNTER_KEY];
    if (!count)
        return;

    if (count.intValue <= 1) {
        [[NSThread currentThread].threadDictionary removeObjectForKey:SENTRY_TRACKING_COUNTER_KEY];
    } else {
        [[NSThread currentThread].threadDictionary
            setObject:[NSNumber numberWithInt:count.intValue - 1]
               forKey:SENTRY_TRACKING_COUNTER_KEY];
    }
}

- (void)finishTrackingNSData:(NSNumber *)length span:(id<SentrySpan>)span
{
    [span setDataValue:length forKey:SentrySpanDataKeyFileSize];
    [span finish];

    SENTRY_LOG_DEBUG(@"Automatically finished span %@", span.description);
}

- (BOOL)ignoreFile:(NSString *)path
{
    SentryFileManager *fileManager = [SentrySDKInternal.currentHub getClient].fileManager;
    return fileManager.sentryPath != nil && [path hasPrefix:fileManager.sentryPath];
}

- (NSString *)transactionDescriptionForFile:(NSString *)path fileSize:(NSUInteger)size
{
    return size > 0 ? [NSString stringWithFormat:@"%@ (%@)", [path lastPathComponent],
                          [SentryByteCountFormatter bytesCountDescription:size]]
                    : [NSString stringWithFormat:@"%@", [path lastPathComponent]];
}

@end
