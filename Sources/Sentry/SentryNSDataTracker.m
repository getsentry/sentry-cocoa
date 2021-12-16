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

- (SentrySpanId *)startTrackingWritingNSData:(NSData *)data
                                    filePath:(NSString *)path
{
    if (![self shouldTrackPath:path])
        return nil;

    SentrySpanId *spanId = [self.tracker startSpanWithName:[path lastPathComponent]
                                                 operation:SENTRY_IO_WRITE_OPERATION];

    id<SentrySpan> span = [self.tracker getSpan:spanId];
    [span setDataValue:[NSNumber numberWithUnsignedInteger:data.length] forKey:@"file.size"];
    [span setDataValue:path forKey:@"file.path"];

    return spanId;
}

- (BOOL)measureNSData:(NSData *)data
          writeToFile:(NSString *)path
           atomically:(BOOL)useAuxiliaryFile
               method:(BOOL (^)(NSString *, BOOL))method
{
    SentrySpanId *spanId = [self startTrackingWritingNSData:data filePath:path];

    BOOL result = method(path, useAuxiliaryFile);

    if (spanId != nil) {
        [self.tracker finishSpan:spanId];
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
        [self.tracker finishSpan:spanId];
    }

    return result;
}



- (NSData *)measureNSDataFromFile:(NSString *)path
                           method:(id (^)(NSString *))method {
    return  method(path);
}


- (NSData *)measureNSDataFromFile:(NSString *)path
                          options:(NSDataReadingOptions)readOptionsMask
                            error:(NSError **)error
                           method:(id (^)(NSString *, NSDataReadingOptions, NSError **))method {
    return method(path, readOptionsMask, error);
}


- (NSData *)measureNSDataFromURL:(NSString *)url
                         options:(NSDataReadingOptions)readOptionsMask
                           error:(NSError **)error
                          method:(id (^)(NSString *, NSDataReadingOptions, NSError **))method {
    return method(url, readOptionsMask, error);
}



- (BOOL)shouldTrackPath:(NSString *)path
{
    return ![path containsString:@"/io.sentry/"];
}

@end
