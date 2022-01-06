#import "SentryNSDataTracker.h"
#import "SentryClient+Private.h"
#import "SentryFileManager.h"
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

    // We dont track reads from a url that is not a file url
    // because these reads are handled by NSURLSession and
    // SentryNetworkTracker will create spans in these cases.
    if (![url.scheme isEqualToString:NSURLFileScheme])
        return method(url, readOptionsMask, error);

    id<SentrySpan> span = [self startTrackingReadingFilePath:url.path];

    NSData *result = method(url, readOptionsMask, error);

    if (span != nil) {
        [self finishTrackingNSData:result span:span];
    }

    return result;
}

- (nullable id<SentrySpan>)spanForPath:(NSString *)path
                             operation:(NSString *)operation
                                  size:(NSUInteger)size
{
    @synchronized(self) {
        if (!self.isEnabled || ![self shouldTrackPath:path])
            return nil;
    }

    __block id<SentrySpan> ioSpan;
    [SentrySDK.currentHub.scope useSpan:^(id<SentrySpan> _Nullable span) {
        ioSpan = [span startChildWithOperation:operation
                                   description:[self transactionDescriptionForFile:path
                                                                          fileSize:size]];
    }];

    [ioSpan setDataValue:path forKey:@"file.path"];
    return ioSpan;
}

- (nullable id<SentrySpan>)startTrackingWritingNSData:(NSData *)data filePath:(NSString *)path
{
    return [self spanForPath:path operation:SENTRY_FILE_WRITE_OPERATION size:data.length];
}

- (nullable id<SentrySpan>)startTrackingReadingFilePath:(NSString *)path
{
    return [self spanForPath:path operation:SENTRY_FILE_READ_OPERATION size:0];
}

- (void)finishTrackingNSData:(NSData *)data span:(id<SentrySpan>)span
{
    [span setDataValue:[NSNumber numberWithUnsignedInteger:data.length] forKey:@"file.size"];
    [span finish];
}

- (BOOL)shouldTrackPath:(NSString *)path
{
    SentryFileManager *fileManager = [SentrySDK.currentHub getClient].fileManager;

    return ![path hasPrefix:fileManager.sentryPath];
}

- (NSString *)transactionDescriptionForFile:(NSString *)path fileSize:(NSUInteger)size
{
    return size > 0
        ? [NSString stringWithFormat:@"%@ (%@)", [path lastPathComponent],
                    [NSByteCountFormatter stringFromByteCount:size
                                                   countStyle:NSByteCountFormatterCountStyleBinary]]
        : [NSString stringWithFormat:@"%@", [path lastPathComponent]];
}

@end
