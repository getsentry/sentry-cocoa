#import "SentryLog.h"
#import "SentryInternalCDefines.h"
#import "SentryLevelMapper.h"
#import "SentryLogSink.h"
#import "SentryLogSinkNSLog.h"
#import "SentryLogSinkFile.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryLog ()

@property (nonatomic, assign, readwrite) BOOL isDebug;
@property (nonatomic, assign, readwrite) SentryLevel diagnosticLevel;

@end

@implementation SentryLog {
    NSObject *_logConfigureLock;
    NSArray<id<SentryLogSink>> *_sinks;
}

+ (instancetype)sharedInstance {
    __block SentryLog *logger;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logger = [[SentryLog alloc] initWithSinks:@[
            [[SentryLogSinkNSLog alloc] init],
            [[SentryLogSinkFile alloc] init],
        ]];
    });
    return logger;
}

- (instancetype)initWithSinks:(NSArray<id<SentryLogSink>> *)sinks
{
    self = [super init];
    if (self) {
        // Enable per default to log initialization errors.
        _isDebug = YES;
        _diagnosticLevel = kSentryLevelError;
        
        _logConfigureLock = [[NSObject alloc] init];
        _sinks = sinks;
    }
    return self;
}

- (void)configure:(BOOL)debug diagnosticLevel:(SentryLevel)level
{
    @synchronized(_logConfigureLock) {
        _isDebug = debug;
        _diagnosticLevel = level;
    }
}

- (void)logWithMessage:(NSString *)message andLevel:(SentryLevel)level
{
    if ([self willLogAtLevel:level]) {
        for (id<SentryLogSink> sink in _sinks) {
            [sink log:[NSString stringWithFormat:@"[Sentry] [%@] %@", nameForSentryLevel(level),
                                     message]];
        }
    }
}

- (BOOL)willLogAtLevel:(SentryLevel)level
    SENTRY_DISABLE_THREAD_SANITIZER(
        "The SDK usually configures the log level and isDebug once when it starts. For tests, we "
        "accept a data race causing some log messages of the wrong level over using a synchronized "
        "block for this method, as it's called frequently in production.")
{
    return _isDebug && level != kSentryLevelNone && level >= _diagnosticLevel;
}

@end

NS_ASSUME_NONNULL_END
