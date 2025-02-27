#import "SentryTraceOrigin.h"

NSString *const SentryTraceOriginAutoAppStart = @"auto.app.start";
NSString *const SentryTraceOriginAutoAppStartProfile = @"auto.app.start.profile";
NSString *const SentryTraceOriginAutoDBCoreData = @"auto.db.core_data";
NSString *const SentryTraceOriginAutoHttpNSURLSession = @"auto.http.ns_url_session";
NSString *const SentryTraceOriginAutoNSData = @"auto.file.ns_data";
NSString *const SentryTraceOriginAutoUiEventTracker = @"auto.ui.event_tracker";
NSString *const SentryTraceOriginAutoUITimeToDisplay = @"auto.ui.time_to_display";
NSString *const SentryTraceOriginAutoUIViewController = @"auto.ui.view_controller";
NSString *const SentryTraceOriginManual = @"manual";
NSString *const SentryTraceOriginManualFileData = @"manual.file.data";
NSString *const SentryTraceOriginManualUITimeToDisplay = @"manual.ui.time_to_display";

@implementation SentryTraceOrigin
+ (NSString *)autoAppStart
{
    return SentryTraceOriginAutoAppStart;
}

+ (NSString *)autoAppStartProfile
{
    return SentryTraceOriginAutoAppStartProfile;
}

+ (NSString *)autoDBCoreData
{
    return SentryTraceOriginAutoDBCoreData;
}

+ (NSString *)autoHttpNSURLSession
{
    return SentryTraceOriginAutoHttpNSURLSession;
}

+ (NSString *)autoNSData
{
    return SentryTraceOriginAutoNSData;
}

+ (NSString *)autoUiEventTracker
{
    return SentryTraceOriginAutoUiEventTracker;
}

+ (NSString *)autoUITimeToDisplay
{
    return SentryTraceOriginAutoUITimeToDisplay;
}

+ (NSString *)autoUIViewController
{
    return SentryTraceOriginAutoUIViewController;
}

+ (NSString *)manual
{
    return SentryTraceOriginManual;
}

+ (NSString *)manualFileData
{
    return SentryTraceOriginManualFileData;
}

+ (NSString *)manualUITimeToDisplay
{
    return SentryTraceOriginManualUITimeToDisplay;
}

@end
