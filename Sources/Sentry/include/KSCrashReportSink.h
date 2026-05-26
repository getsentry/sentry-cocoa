#import "SentryDefines.h"
#import <Foundation/Foundation.h>
@import KSCrashRecording;

@class SentryInAppLogic;

NS_ASSUME_NONNULL_BEGIN

/**
 * A KSCrash report filter that converts KSCrash crash reports into Sentry events
 * and sends them via @c SentrySDKInternal.
 *
 * This is the KSCrash-v2 counterpart to @c SentryCrashReportSink.
 * Key difference: reports arrive as @c KSCrashReportDictionary objects
 * rather than raw @c NSDictionary values.
 */
@interface KSCrashReportSink : NSObject <KSCrashReportFilter>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithInAppLogic:(SENTRY_SWIFT_MIGRATION_ID(SentryInAppLogic))inAppLogic
    NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
