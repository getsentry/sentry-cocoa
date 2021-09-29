#import "SentryNSDataTracker.h"

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

@end
