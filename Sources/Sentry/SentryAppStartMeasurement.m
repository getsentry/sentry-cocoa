#import "SentryAppStartMeasurement.h"

#if SENTRY_UIKIT_AVAILABLE

#    import "NSDate+SentryExtras.h"
#    import "SentryLog.h"
#    import <Foundation/Foundation.h>

@implementation SentryAppStartMeasurement
#    if SENTRY_HAS_UIKIT
{
    SentryAppStartType _type;
    BOOL _isPreWarmed;
    NSTimeInterval _duration;
    NSDate *_appStartTimestamp;
    NSDate *_runtimeInitTimestamp;
    NSDate *_moduleInitializationTimestamp;
    NSDate *_didFinishLaunchingTimestamp;
}
#    endif // SENTRY_HAS_UIKIT

- (instancetype)initWithType:(SentryAppStartType)type
              appStartTimestamp:(NSDate *)appStartTimestamp
                       duration:(NSTimeInterval)duration
           runtimeInitTimestamp:(NSDate *)runtimeInitTimestamp
    didFinishLaunchingTimestamp:(NSDate *)didFinishLaunchingTimestamp
{
#    if SENTRY_HAS_UIKIT
    return [self initWithType:type
                          isPreWarmed:NO
                    appStartTimestamp:appStartTimestamp
                             duration:duration
                 runtimeInitTimestamp:runtimeInitTimestamp
        moduleInitializationTimestamp:[NSDate dateWithTimeIntervalSince1970:0]
          didFinishLaunchingTimestamp:didFinishLaunchingTimestamp];
#    else
    SENTRY_LOG_DEBUG(@"SentryAppStartMeasurement is only available in builds that link UIKit.");
    return nil;
#    endif // SENTRY_HAS_UIKIT
}

- (instancetype)initWithType:(SentryAppStartType)type
                      isPreWarmed:(BOOL)isPreWarmed
                appStartTimestamp:(NSDate *)appStartTimestamp
                         duration:(NSTimeInterval)duration
             runtimeInitTimestamp:(NSDate *)runtimeInitTimestamp
    moduleInitializationTimestamp:(NSDate *)moduleInitializationTimestamp
      didFinishLaunchingTimestamp:(NSDate *)didFinishLaunchingTimestamp
{
#    if SENTRY_HAS_UIKIT
    if (self = [super init]) {
        _type = type;
        _isPreWarmed = isPreWarmed;
        _appStartTimestamp = appStartTimestamp;
        _duration = duration;
        _runtimeInitTimestamp = runtimeInitTimestamp;
        _moduleInitializationTimestamp = moduleInitializationTimestamp;
        _didFinishLaunchingTimestamp = didFinishLaunchingTimestamp;
    }

    return self;
#    else
    SENTRY_LOG_DEBUG(@"SentryAppStartMeasurement is only available in builds that link UIKit.");
    return nil;
#    endif // SENTRY_HAS_UIKIT
}

- (SentryAppStartType)type
{
#    if SENTRY_HAS_UIKIT
    return _type;
#    else
    SENTRY_LOG_DEBUG(@"type is only available in builds that link UIKit.");
    return SentryAppStartTypeUnknown;
#    endif // SENTRY_HAS_UIKIT
}

- (BOOL)isPreWarmed
{
#    if SENTRY_HAS_UIKIT
    return _isPreWarmed;
#    else
    SENTRY_LOG_DEBUG(@"isPreWarmed is only available in builds that link UIKit.");
    return NO;
#    endif // SENTRY_HAS_UIKIT
}

- (NSTimeInterval)duration
{
#    if SENTRY_HAS_UIKIT
    return _duration;
#    else
    SENTRY_LOG_DEBUG(@"duration is only available in builds that link UIKit.");
    return 0.0;
#    endif // SENTRY_HAS_UIKIT
}

- (NSDate *)appStartTimestamp
{
#    if SENTRY_HAS_UIKIT
    return _appStartTimestamp;
#    else
    SENTRY_LOG_DEBUG(@"appStartTimestamp is only available in builds that link UIKit.");
    return nil;
#    endif // SENTRY_HAS_UIKIT
}

- (NSDate *)runtimeInitTimestamp
{
#    if SENTRY_HAS_UIKIT
    return _runtimeInitTimestamp;
#    else
    SENTRY_LOG_DEBUG(@"runtimeInitTimestamp is only available in builds that link UIKit.");
    return nil;
#    endif // SENTRY_HAS_UIKIT
}

- (NSDate *)moduleInitializationTimestamp
{
#    if SENTRY_HAS_UIKIT
    return _moduleInitializationTimestamp;
#    else
    SENTRY_LOG_DEBUG(@"moduleInitializationTimestamp is only available in builds that link UIKit.");
    return nil;
#    endif // SENTRY_HAS_UIKIT
}

- (NSDate *)didFinishLaunchingTimestamp
{
#    if SENTRY_HAS_UIKIT
    return _didFinishLaunchingTimestamp;
#    else
    SENTRY_LOG_DEBUG(@"didFinishLaunchingTimestamp is only available in builds that link UIKit.");
    return nil;
#    endif // SENTRY_HAS_UIKIT
}

@end

#endif // SENTRY_UIKIT_AVAILABLE
