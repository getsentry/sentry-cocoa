#import "SentryReplaySettings.h"


@interface SentryReplaySettings ()

@property (nonatomic) NSInteger replayBitRate;

@end

@implementation SentryReplaySettings

-(instancetype)init {
    if (self = [super init]) {
        self.replaysSessionSampleRate = 0;
        self.replaysOnErrorSampleRate = 0;
        self.replayBitRate = 20000;
    }
    return self;
}

- (instancetype)initWithReplaySessionSampleRate:(CGFloat)sessionSampleRate replaysOnErrorSampleRate:(CGFloat)errorSampleRate {
    if (self = [self init]) {
        self.replaysSessionSampleRate = sessionSampleRate;
        self.replaysOnErrorSampleRate = errorSampleRate;
    }
    
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary*)dictionary {
    if (self = [self init]) {
        if ([dictionary[@"replaysSessionSampleRate"] isKindOfClass:NSNumber.class]) {
            self.replaysSessionSampleRate = [dictionary[@"replaysSessionSampleRate"] floatValue];
        }
        
        if ([dictionary[@"replaysOnErrorSampleRate"] isKindOfClass:NSNumber.class]) {
            self.replaysOnErrorSampleRate = [dictionary[@"replaysOnErrorSampleRate"] floatValue];
        }
    }
    return self;
}

@end
