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

- (BOOL)traceWriteToFile:(NSString *)path
              atomically:(BOOL)useAuxiliaryFile
                  method:(BOOL (^)(NSString *, BOOL))method
{
    SentrySpanId *spanId = [self.tracker startSpanWithName:@"WRITING_FILE"
                                                 operation:SENTRY_IO_OPERATION];

    id<SentrySpan> span = [self.tracker getSpan:spanId];
    [span setDataValue:path forKey:@"path"];

    BOOL result = method(path, useAuxiliaryFile);
    [self.tracker finishSpan:spanId];
    return result;
}

- (BOOL)traceWriteToFile:(NSString *)path
                 options:(NSDataWritingOptions)writeOptionsMask
                   error:(NSError **)error
                  method:(BOOL (^)(NSString *, NSDataWritingOptions, NSError **))method
{
    SentrySpanId *spanId = [self.tracker startSpanWithName:@"WRITING_FILE"
                                                 operation:SENTRY_IO_OPERATION];

    id<SentrySpan> span = [self.tracker getSpan:spanId];
    [span setDataValue:path forKey:@"path"];

    BOOL result = method(path, writeOptionsMask, error);
    [self.tracker finishSpan:spanId];
    return result;
}

@end
