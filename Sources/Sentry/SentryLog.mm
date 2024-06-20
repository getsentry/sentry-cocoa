#import "SentryLog.h"
#import "SentryInternalCDefines.h"
#import "SentryLevelMapper.h"
#import "SentryLogSink.h"
#import "SentryLogSinkFile.h"
#import "SentryLogSinkNSLog.h"
#include <map>
#include <mutex>

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    bool isDebug;
    SentryLevel diagnosticLevel;
} SentryLoggerConfiguration;

namespace {
    std::map<const char *, SentryLoggerConfiguration> _gLoggerConfigurations;
    std::mutex _gLogConfigureLock;
} // namespace

BOOL loggerWillLogAtLevel(const char *loggerLabel, SentryLevel level)
    SENTRY_DISABLE_THREAD_SANITIZER(
        "The SDK usually configures the log level and isDebug once when it starts. For tests, we "
        "accept a data race causing some log messages of the wrong level over using a synchronized "
        "block for this method, as it's called frequently in production.")
{
    const auto config = _gLoggerConfigurations[loggerLabel];
    return config.isDebug && level != kSentryLevelNone && level >= config.diagnosticLevel;
}

@implementation SentryLog {
    NSArray<id<SentryLogSink>> *_sinks;
}

+ (instancetype)sharedInstance
{
    __block SentryLog *logger;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logger = [[SentryLog alloc] initWithLabel:"io.sentry.sdk.logger.default" sinks:@[
            [[SentryLogSinkNSLog alloc] init],
            [[SentryLogSinkFile alloc] init],
        ]];
    });
    return logger;
}

- (instancetype)initWithLabel:(const char *)label sinks:(NSArray<id<SentryLogSink>> *)sinks
{
    self = [super init];
    if (self) {
        // Enable per default to log initialization errors.
        [self configure:YES diagnosticLevel:kSentryLevelError];
        
        static dispatch_once_t loggerConfigurationMapInitOnceToken;
        dispatch_once(&loggerConfigurationMapInitOnceToken, ^{
            _gLoggerConfigurations = std::map<const char *, SentryLoggerConfiguration>();
        });
        
        _sinks = sinks;
        _label = label;
    }
    return self;
}

- (void)configure:(BOOL)debug diagnosticLevel:(SentryLevel)level
{
    std::lock_guard<std::mutex> l(_gLogConfigureLock);
    _gLoggerConfigurations[_label] = { debug, level };
}

- (void)logWithMessage:(NSString *)message andLevel:(SentryLevel)level
{
    if (loggerWillLogAtLevel(_label, level)) {
        for (id<SentryLogSink> sink in _sinks) {
            [sink log:[NSString stringWithFormat:@"[Sentry] [%@] %@", nameForSentryLevel(level),
                                message]];
        }
    }
}

@end

NS_ASSUME_NONNULL_END
