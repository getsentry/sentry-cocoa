#import "SentryFileIOTracker.h"
#import "SentryByteCountFormatter.h"
#import "SentryClient+Private.h"
#import "SentryDependencyContainer.h"
#import "SentryFileManager.h"
#import "SentryFrame.h"
#import "SentryHub+Private.h"
#import "SentryInternalDefines.h"
#import "SentryLog.h"
#import "SentryNSProcessInfoWrapper.h"
#import "SentryOptions.h"
#import "SentrySDK+Private.h"
#import "SentryScope+Private.h"
#import "SentrySpan.h"
#import "SentrySpanProtocol.h"
#import "SentryStacktrace.h"
#import "SentrySwift.h"
#import "SentryThread.h"
#import "SentryThreadInspector.h"
#import "SentryTracer.h"

@interface SentryFileIOTracker ()

@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, strong) NSMutableSet<NSData *> *processingData;
@property (nonatomic, strong) SentryThreadInspector *threadInspector;
@property (nonatomic, strong) SentryNSProcessInfoWrapper *processInfoWrapper;

@end

@implementation SentryFileIOTracker

NSString *const SENTRY_TRACKING_COUNTER_KEY = @"SENTRY_TRACKING_COUNTER_KEY";

+ (instancetype)sharedInstance
{
    return SentryDependencyContainer.sharedInstance.fileIOTracker;
}

- (instancetype)initWithThreadInspector:(SentryThreadInspector *)threadInspector
                     processInfoWrapper:(SentryNSProcessInfoWrapper *)processInfoWrapper
{
    if (self = [super init]) {
        _processInfoWrapper = processInfoWrapper;
        _threadInspector = threadInspector;
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
               method:(BOOL (^)(NSString *, BOOL))method
{
    id<SentrySpan> span = [self startTrackingWritingNSData:data filePath:path origin:origin];

    BOOL result = method(path, useAuxiliaryFile);

    if (span != nil) {
        [self finishTrackingNSData:data span:span];
    }
    return result;
}

- (BOOL)measureNSData:(NSData *)data
          writeToFile:(NSString *)path
              options:(NSDataWritingOptions)writeOptionsMask
               origin:(NSString *)origin
                error:(NSError **)error
               method:(BOOL (^)(NSString *, NSDataWritingOptions, NSError **))method
{
    id<SentrySpan> span = [self startTrackingWritingNSData:data filePath:path origin:origin];

    BOOL result = method(path, writeOptionsMask, error);

    if (span != nil) {
        [self finishTrackingNSData:data span:span];
    }

    return result;
}

- (BOOL)measureNSData:(NSData *)data
           writeToURL:(NSURL *)url
              options:(NSDataWritingOptions)writeOptionsMask
               origin:(NSString *)origin
                error:(NSError **)error
               method:(BOOL (^)(NSURL *, NSDataWritingOptions, NSError **))method
{
    // We dont track reads from a url that is not a file url
    // because these reads are handled by NSURLSession and
    // SentryNetworkTracker will create spans in these cases.
    if (![url.scheme isEqualToString:NSURLFileScheme])
        return method(url, writeOptionsMask, error);

    id<SentrySpan> span = [self startTrackingWritingNSData:data filePath:[url path] origin:origin];

    BOOL result = method(url, writeOptionsMask, error);

    if (span != nil) {
        [self finishTrackingNSData:data span:span];
    }

    return result;
}

- (NSData *)measureNSDataFromFile:(NSString *)path
                           origin:(NSString *)origin
                           method:(NSData * (^)(NSString *))method
{
    id<SentrySpan> span = [self startTrackingReadingFilePath:path
                                                      origin:origin
                                                   operation:SentrySpanOperation.fileRead];

    NSData *result = method(path);

    if (span != nil) {
        [self finishTrackingNSData:result span:span];
    }

    [self endTrackingFile];
    return result;
}

- (NSData *)measureNSDataFromFile:(NSString *)path
                          options:(NSDataReadingOptions)readOptionsMask
                           origin:(NSString *)origin
                            error:(NSError **)error
                           method:(NSData * (^)(NSString *, NSDataReadingOptions, NSError **))method
{
    id<SentrySpan> span = [self startTrackingReadingFilePath:path
                                                      origin:origin
                                                   operation:SentrySpanOperation.fileRead];

    NSData *result = method(path, readOptionsMask, error);

    if (span != nil) {
        [self finishTrackingNSData:result span:span];
    }

    [self endTrackingFile];
    return result;
}

- (NSData *)measureNSDataFromURL:(NSURL *)url
                         options:(NSDataReadingOptions)readOptionsMask
                          origin:(NSString *)origin
                           error:(NSError **)error
                          method:(NSData * (^)(NSURL *, NSDataReadingOptions, NSError **))method
{

    // We dont track reads from a url that is not a file url
    // because these reads are handled by NSURLSession and
    // SentryNetworkTracker will create spans in these cases.
    if (![url.scheme isEqualToString:NSURLFileScheme])
        return method(url, readOptionsMask, error);

    id<SentrySpan> span = [self startTrackingReadingFilePath:url.path
                                                      origin:origin
                                                   operation:SentrySpanOperation.fileRead];

    NSData *result = method(url, readOptionsMask, error);

    if (span != nil) {
        [self finishTrackingNSData:result span:span];
    }

    [self endTrackingFile];
    return result;
}

- (BOOL)measureNSFileManagerCreateFileAtPath:(NSString *)path
                                        data:(NSData *)data
                                  attributes:(NSDictionary<NSFileAttributeKey, id> *)attributes
                                      origin:(NSString *)origin
                                      method:
                                          (BOOL (^)(NSString *_Nonnull, NSData *_Nonnull,
                                              NSDictionary<NSFileAttributeKey, id> *_Nonnull))method
{
    id<SentrySpan> span = [self startTrackingWritingNSData:data filePath:path origin:origin];

    BOOL result = method(path, data, attributes);

    if (span != nil) {
        [self finishTrackingNSData:data span:span];
    }
    return result;
}

- (nullable id<SentrySpan>)spanForPath:(NSString *)path
                                origin:(NSString *)origin
                             operation:(NSString *)operation
{
    return [self spanForPath:path origin:origin operation:operation size:0];
}

- (nullable id<SentrySpan>)spanForPath:(NSString *)path
                                origin:(NSString *)origin
                             operation:(NSString *)operation
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

    __block id<SentrySpan> ioSpan;
    [SentrySDK.currentHub.scope useSpan:^(id<SentrySpan> _Nullable span) {
        ioSpan = [span startChildWithOperation:operation
                                   description:[self transactionDescriptionForFile:path
                                                                          fileSize:size]];
        ioSpan.origin = origin;
        if (size > 0) {
            [ioSpan setDataValue:[NSNumber numberWithUnsignedInteger:size]
                          forKey:SentrySpanDataKey.fileSize];
        }
    }];

    if (ioSpan == nil) {
        SENTRY_LOG_DEBUG(@"No transaction bound to scope. Won't track file IO operation.");
        return nil;
    }

    SENTRY_LOG_DEBUG(@"Automatically started a new span with description: %@, operation: %@",
        ioSpan.description, operation);

    [ioSpan setDataValue:path forKey:SentrySpanDataKey.filePath];

    [self mainThreadExtraInfo:ioSpan];

    return ioSpan;
}

- (void)mainThreadExtraInfo:(id<SentrySpan>)span
{
    BOOL isMainThread = [NSThread isMainThread];

    [span setDataValue:@(isMainThread) forKey:SPAN_DATA_BLOCKED_MAIN_THREAD];

    if (!isMainThread) {
        return;
    }

    SentryThreadInspector *threadInspector = self.threadInspector;
    SentryStacktrace *stackTrace = [threadInspector stacktraceForCurrentThreadAsyncUnsafe];

    NSArray *frames = [stackTrace.frames
        filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(SentryFrame *frame,
                                        NSDictionary<NSString *, id> *bindings) {
            return [frame.package hasPrefix:self.processInfoWrapper.processDirectoryPath];
        }]];

    if (frames.count <= 1) {
        // This means the call was made only by system APIs
        // and only the 'main' frame remains in the stack
        // therefore, there is nothing to do about it
        // and we should not report it as an issue.
        [span setDataValue:@(NO) forKey:SPAN_DATA_BLOCKED_MAIN_THREAD];
    } else {
        [((SentrySpan *)span) setFrames:frames];
    }
}

- (nullable id<SentrySpan>)startTrackingWritingNSData:(NSData *)data
                                             filePath:(NSString *)path
                                               origin:(NSString *)origin
{
    return [self spanForPath:path
                      origin:origin
                   operation:SentrySpanOperation.fileWrite
                        size:data.length];
}

- (nullable id<SentrySpan>)startTrackingReadingFilePath:(NSString *)path
                                                 origin:(NSString *)origin
                                              operation:(NSString *)operation
{
    // Some iOS versions nest constructors calls. This counter help us avoid create more than one
    // span for the same operation.
    NSNumber *count =
        [[NSThread currentThread].threadDictionary objectForKey:SENTRY_TRACKING_COUNTER_KEY];
    [[NSThread currentThread].threadDictionary setObject:[NSNumber numberWithInt:count.intValue + 1]
                                                  forKey:SENTRY_TRACKING_COUNTER_KEY];

    if (count)
        return nil;

    return [self spanForPath:path origin:origin operation:operation size:0];
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

- (void)finishTrackingNSData:(NSData *)data span:(id<SentrySpan>)span
{
    [span setDataValue:[NSNumber numberWithUnsignedInteger:data.length]
                forKey:SentrySpanDataKey.fileSize];
    [span finish];

    SENTRY_LOG_DEBUG(@"Automatically finished span %@", span.description);
}

- (BOOL)ignoreFile:(NSString *)path
{
    SentryFileManager *fileManager = [SentrySDK.currentHub getClient].fileManager;
    return fileManager.sentryPath != nil && [path hasPrefix:fileManager.sentryPath];
}

- (NSString *)transactionDescriptionForFile:(NSString *)path fileSize:(NSUInteger)size
{
    return size > 0 ? [NSString stringWithFormat:@"%@ (%@)", [path lastPathComponent],
                          [SentryByteCountFormatter bytesCountDescription:size]]
                    : [NSString stringWithFormat:@"%@", [path lastPathComponent]];
}

@end
