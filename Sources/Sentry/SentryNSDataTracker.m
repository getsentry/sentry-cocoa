#import "SentryNSDataTracker.h"
#import "SentryHub+Private.h"
#import "SentryLog.h"
#import "SentryPerformanceTracker.h"
#import "SentrySDK+Private.h"
#import "SentryScope+Private.h"
#import "SentrySpanProtocol.h"

@interface
SentryNSDataTracker ()

@property (nonatomic, assign) BOOL isEnabled;

@end

@implementation SentryNSDataTracker

+ (SentryNSDataTracker *)sharedInstance
{
    static SentryNSDataTracker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.isEnabled = NO;
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

- (NSString *)transactionDescriptionForFile:(NSString *)path fileSize:(NSUInteger)size
{
    return size > 0
        ? [NSString stringWithFormat:@"%@ (%@)", [path lastPathComponent],
                    [NSByteCountFormatter stringFromByteCount:size
                                                   countStyle:NSByteCountFormatterCountStyleFile]]
        : [NSString stringWithFormat:@"%@", [path lastPathComponent]];
}

- (nullable id<SentrySpan>)startTrackingWritingNSData:(NSData *)data filePath:(NSString *)path
{
    if (!self.isEnabled || ![self shouldTrackPath:path])
        return nil;
    __block id<SentrySpan> ioSpan;
    [SentrySDK.currentHub.scope useSpan:^(id<SentrySpan> _Nullable span) {
        ioSpan = [span startChildWithOperation:SENTRY_FILE_WRITE_OPERATION
                                   description:[self transactionDescriptionForFile:path
                                                                          fileSize:data.length]];
    }];

    // We only create a span if there is a transaction in the scope,
    // otherwise we have nothing else to do here.
    if (ioSpan == nil)
        return nil;

    [ioSpan setDataValue:path forKey:@"file.path"];
    return ioSpan;
}

- (id<SentrySpan>)startTrackingReadingFilePath:(NSString *)path
{
    if (!self.isEnabled || ![self shouldTrackPath:path])
        return nil;

    __block id<SentrySpan> ioSpan;
    [SentrySDK.currentHub.scope useSpan:^(id<SentrySpan> _Nullable span) {
        ioSpan = [span startChildWithOperation:SENTRY_FILE_READ_OPERATION
                                   description:[self transactionDescriptionForFile:path
                                                                          fileSize:0]];
    }];

    [ioSpan setDataValue:path forKey:@"file.path"];

    return ioSpan;
}

- (void)finishTrackingNSData:(NSData *)data span:(id<SentrySpan>)span
{
    [span setDataValue:[NSNumber numberWithUnsignedInteger:data.length] forKey:@"file.size"];
    [span finish];
}

- (BOOL)measureNSData:(NSData *)data
          writeToFile:(NSString *)path
           atomically:(BOOL)useAuxiliaryFile
               method:(BOOL (^)(NSString *, BOOL))method
{
    id<SentrySpan> span = [self startTrackingWritingNSData:data filePath:path];

    BOOL result = method(path, useAuxiliaryFile);

    if (span != nil) {
        [self finishTrackingNSData:data span:span];
    }
    return result;
}

- (BOOL)measureNSData:(NSData *)data
          writeToFile:(NSString *)path
              options:(NSDataWritingOptions)writeOptionsMask
                error:(NSError **)error
               method:(BOOL (^)(NSString *, NSDataWritingOptions, NSError **))method
{
    id<SentrySpan> span = [self startTrackingWritingNSData:data filePath:path];

    BOOL result = method(path, writeOptionsMask, error);

    if (span != nil) {
        [self finishTrackingNSData:data span:span];
    }

    return result;
}

- (NSData *)measureNSDataFromFile:(NSString *)path method:(NSData * (^)(NSString *))method
{
    id<SentrySpan> span = [self startTrackingReadingFilePath:path];

    NSData *result = method(path);

    if (span != nil) {
        [self finishTrackingNSData:result span:span];
    }

    return result;
}

- (NSData *)measureNSDataFromFile:(NSString *)path
                          options:(NSDataReadingOptions)readOptionsMask
                            error:(NSError **)error
                           method:(NSData * (^)(NSString *, NSDataReadingOptions, NSError **))method
{
    id<SentrySpan> span = [self startTrackingReadingFilePath:path];

    NSData *result = method(path, readOptionsMask, error);

    if (span != nil) {
        [self finishTrackingNSData:result span:span];
    }

    return result;
}

- (NSData *)measureNSDataFromURL:(NSURL *)url
                         options:(NSDataReadingOptions)readOptionsMask
                           error:(NSError **)error
                          method:(NSData * (^)(NSURL *, NSDataReadingOptions, NSError **))method
{
    if (![url.scheme isEqualToString:NSURLFileScheme])
        return method(url, readOptionsMask, error);

    id<SentrySpan> span = [self startTrackingReadingFilePath:url.absoluteString];

    NSData *result = method(url, readOptionsMask, error);

    if (span != nil) {
        [self finishTrackingNSData:result span:span];
    }

    return result;
}

- (BOOL)shouldTrackPath:(NSString *)path
{
    return ![path containsString:@"/io.sentry/"];
}

@end
