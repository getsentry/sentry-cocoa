#import <Foundation/Foundation.h>

static NSString *const SentryTraceOriginManual = @"manual";
static NSString *const SentryTraceOriginUIEventTracker = @"auto.ui.event_tracker";

static NSString *const SentryTraceOriginAuto = @"auto";
static NSString *const SentryTraceOriginAutoAppStart = @"auto.app.start";
static NSString *const SentryTraceOriginAutoFile = @"auto.file";
static NSString *const SentryTraceOriginAutoUIViewController = @"auto.ui.view_controller";
static NSString *const SentryTraceOriginAutoUITimeToDisplay = @"auto.ui.time_to_display";
