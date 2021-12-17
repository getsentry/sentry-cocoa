#import "SentryNSDataTracker.h"
#import "SentryPerformanceTracker.h"
#import "SentrySpanProtocol.h"

@interface
SentryNSDataTracker ()

@property (nonatomic, assign) BOOL isEnabled;

@property (nonatomic, strong) SentryPerformanceTracker *tracker;

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
        self.tracker = SentryPerformanceTracker.shared;
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

- (NSString *)transactionDescriptionForFile:(NSString *)path fileSize:(unsigned long)size
{
    return size > 0
        ? [NSString stringWithFormat:@"%@ (%@)", [path lastPathComponent],
                    [NSByteCountFormatter stringFromByteCount:size
                                                   countStyle:NSByteCountFormatterCountStyleFile]]
        : [NSString stringWithFormat:@"%@", [path lastPathComponent]];
}

- (SentrySpanId *)startTrackingWritingNSData:(NSData *)data filePath:(NSString *)path
{
    if (!self.isEnabled || ![self shouldTrackPath:path])
        return nil;

    SentrySpanId *spanId = [self.tracker
        startSpanWithName:[self transactionDescriptionForFile:path fileSize:data.length]
                operation:SENTRY_IO_WRITE_OPERATION];

    id<SentrySpan> span = [self.tracker getSpan:spanId];
    [span setDataValue:path forKey:@"file.path"];
    return spanId;
}

- (SentrySpanId *)startTrackingReadingFilePath:(NSString *)path
{
    return [self.tracker startSpanWithName:[self transactionDescriptionForFile:path fileSize:0]
                                 operation:SENTRY_IO_READ_OPERATION];
}

- (void)finishTrackingNSData:(NSData *)data spanId:(SentrySpanId *)spanId
{
    id<SentrySpan> span = [self.tracker getSpan:spanId];
    [span setDataValue:[NSNumber numberWithUnsignedInteger:data.length] forKey:@"file.size"];
    [self.tracker finishSpan:spanId];
}

- (BOOL)measureNSData:(NSData *)data
          writeToFile:(NSString *)path
           atomically:(BOOL)useAuxiliaryFile
               method:(BOOL (^)(NSString *, BOOL))method
{
    SentrySpanId *spanId = [self startTrackingWritingNSData:data filePath:path];

    BOOL result = method(path, useAuxiliaryFile);

    if (spanId != nil) {
        [self finishTrackingNSData:data spanId:spanId];
    }
    return result;
}

- (BOOL)measureNSData:(NSData *)data
          writeToFile:(NSString *)path
              options:(NSDataWritingOptions)writeOptionsMask
                error:(NSError **)error
               method:(BOOL (^)(NSString *, NSDataWritingOptions, NSError **))method
{
    SentrySpanId *spanId = [self startTrackingWritingNSData:data filePath:path];

    BOOL result = method(path, writeOptionsMask, error);

    if (spanId != nil) {
        [self finishTrackingNSData:data spanId:spanId];
    }

    return result;
}

- (NSData *)measureNSDataFromFile:(NSString *)path method:(NSData * (^)(NSString *))method
{
    SentrySpanId *spanId = [self startTrackingReadingFilePath:path];

    NSData *result = method(path);

    if (spanId != nil) {
        [self finishTrackingNSData:result spanId:spanId];
    }

    return result;
}

- (NSData *)measureNSDataFromFile:(NSString *)path
                          options:(NSDataReadingOptions)readOptionsMask
                            error:(NSError **)error
                           method:(NSData * (^)(NSString *, NSDataReadingOptions, NSError **))method
{
    SentrySpanId *spanId = [self startTrackingReadingFilePath:path];

    NSData *result = method(path, readOptionsMask, error);

    if (spanId != nil) {
        [self finishTrackingNSData:result spanId:spanId];
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

    SentrySpanId *spanId = [self startTrackingReadingFilePath:url.absoluteString];

    NSData *result = method(url, readOptionsMask, error);

    if (spanId != nil) {
        [self finishTrackingNSData:result spanId:spanId];
    }

    return result;
}

- (BOOL)shouldTrackPath:(NSString *)path
{
    return ![path containsString:@"/io.sentry/"];
}

@end
