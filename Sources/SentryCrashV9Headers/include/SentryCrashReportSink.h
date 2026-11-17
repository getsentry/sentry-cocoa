#import "SentryCrash.h"
#import "SentryDefines.h"

@protocol SentryCrashReporter;
@class SentryCrashHandlerEventSource;
@class SentryDispatchQueueWrapper;
@class SentryInAppLogic;
@class SentryStartupCrashFlush;

NS_ASSUME_NONNULL_BEGIN

@interface SentryCrashReportSink : NSObject <SentryCrashReportFilter>
SENTRY_NO_INIT

/**
 * @param crashHandlerEventSource Takes the events converted from the stored crash reports.
 */
- (instancetype)
         initWithInAppLogic:(SENTRY_SWIFT_MIGRATION_ID(SentryInAppLogic))inAppLogic
               crashWrapper:(SENTRY_SWIFT_MIGRATION_ID(SentryCrashReporter))crashWrapper
              dispatchQueue:(SENTRY_SWIFT_MIGRATION_ID(SentryDispatchQueueWrapper))dispatchQueue
          startupCrashFlush:(SENTRY_SWIFT_MIGRATION_ID(SentryStartupCrashFlush))startupCrashFlush
    crashHandlerEventSource:
        (SENTRY_SWIFT_MIGRATION_ID(SentryCrashHandlerEventSource))crashHandlerEventSource;

@end

NS_ASSUME_NONNULL_END
