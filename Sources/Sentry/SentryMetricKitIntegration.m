#import <SentryMetricKitIntegration.h>

#if SENTRY_HAS_METRIC_KIT

#    import "SentryInternalDefines.h"
#    import "SentryScope.h"
#    import "SentrySwift.h"
#    import <Foundation/Foundation.h>
#    import <SentryAttachment.h>
#    import <SentryDebugMeta.h>
#    import <SentryEvent.h>
#    import <SentryException.h>
#    import <SentryFormatter.h>
#    import <SentryFrame.h>
#    import <SentryLogC.h>
#    import <SentryMechanism.h>
#    import <SentrySDK+Private.h>
#    import <SentryStacktrace.h>
#    import <SentryThread.h>

/**
 * We need to check if MetricKit is available for compatibility on iOS 12 and below. As there are no
 * compiler directives for iOS versions we use __has_include.
 */
#    if __has_include(<MetricKit/MetricKit.h>)
#        import <MetricKit/MetricKit.h>
#    endif // __has_include(<MetricKit/MetricKit.h>)

NS_ASSUME_NONNULL_BEGIN

@interface SentryMXExceptionParams : NSObject

@property (nonatomic, assign) BOOL handled;
@property (nonatomic, assign) SentryLevel level;
@property (nonatomic, copy) NSString *exceptionValue;
@property (nonatomic, copy) NSString *exceptionType;
@property (nonatomic, copy) NSString *exceptionMechanism;
@property (nonatomic, copy) NSDate *timeStampBegin;

@end

@implementation SentryMXExceptionParams

@end

API_AVAILABLE(macos(12.0))
@interface SentryMetricKitIntegration () <SentryMXManagerDelegate>

@property (nonatomic, strong, nullable) SentryMXManager *metricKitManager;
@property (nonatomic, strong) NSMeasurementFormatter *measurementFormatter;
@property (nonatomic, strong, nullable) SentryInAppLogic *inAppLogic;
@property (nonatomic, assign) BOOL attachDiagnosticAsAttachment;

@end

API_AVAILABLE(macos(12.0))
@implementation SentryMetricKitIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    self.metricKitManager = [SentryDependencyContainer sharedInstance].metricKitManager;
    self.metricKitManager.delegate = self;
    [self.metricKitManager receiveReports];
    self.measurementFormatter = [[NSMeasurementFormatter alloc] init];
    self.measurementFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    self.measurementFormatter.unitOptions = NSMeasurementFormatterUnitOptionsProvidedUnit;
    self.inAppLogic = [[SentryInAppLogic alloc] initWithInAppIncludes:options.inAppIncludes];
    self.attachDiagnosticAsAttachment = options.enableMetricKitRawPayload;

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableMetricKit;
}

- (void)uninstall
{
    [self.metricKitManager pauseReports];
    self.metricKitManager.delegate = nil;
    self.metricKitManager = nil;
}

/**
 * Only for testing. We need to publish the iOS-Swift sample app to TestFlight for properly testing
 * this. We easily get MXCrashDiagnostic and so we can use them for validating symbolication. We
 * don't plan on releasing this. Instead, we are going to remove this code before releasing.
 */
- (void)didReceiveCrashDiagnostic:(MXCrashDiagnostic *)diagnostic
                    callStackTree:(SentryMXCallStackTree *)callStackTree
                   timeStampBegin:(NSDate *)timeStampBegin
                     timeStampEnd:(NSDate *)timeStampEnd
{
    NSString *exceptionValue =
        [NSString stringWithFormat:@"MachException Type:%@ Code:%@ Signal:%@",
            diagnostic.exceptionType, diagnostic.exceptionCode, diagnostic.signal];

    SentryMXExceptionParams *params = [[SentryMXExceptionParams alloc] init];
    params.handled = NO;
    params.level = kSentryLevelError;
    params.exceptionValue = exceptionValue;
    params.exceptionType = @"MXCrashDiagnostic";
    params.exceptionMechanism = @"MXCrashDiagnostic";
    params.timeStampBegin = timeStampBegin;

    [self captureMXEvent:callStackTree
                  params:params
          diagnosticJSON:[diagnostic JSONRepresentation]];
}

- (void)didReceiveCpuExceptionDiagnostic:(MXCPUExceptionDiagnostic *)diagnostic
                           callStackTree:(SentryMXCallStackTree *)callStackTree
                          timeStampBegin:(NSDate *)timeStampBegin
                            timeStampEnd:(NSDate *)timeStampEnd
{
    // MXCPUExceptionDiagnostics call stacks point to hot spots in code and aren't organized per
    // thread. See https://developer.apple.com/videos/play/wwdc2020/10078/?time=224
    if (callStackTree.callStackPerThread) {
        SENTRY_LOG_WARN(@"MXCPUExceptionDiagnostics aren't expected to have call stacks per "
                        @"thread. Ignoring it.");
        return;
    }

    NSString *totalCPUTime =
        [self.measurementFormatter stringFromMeasurement:diagnostic.totalCPUTime];
    NSString *totalSampledTime =
        [self.measurementFormatter stringFromMeasurement:diagnostic.totalSampledTime];

    NSString *exceptionValue =
        [NSString stringWithFormat:@"MXCPUException totalCPUTime:%@ totalSampledTime:%@",
            totalCPUTime, totalSampledTime];

    // Still need to figure out proper exception values and types.
    // This code is currently only there for testing with TestFlight.
    SentryMXExceptionParams *params = [[SentryMXExceptionParams alloc] init];
    params.handled = YES;
    params.level = kSentryLevelWarning;
    params.exceptionValue = exceptionValue;
    params.exceptionType = SentryMetricKitCpuExceptionType;
    params.exceptionMechanism = SentryMetricKitCpuExceptionMechanism;
    params.timeStampBegin = timeStampBegin;

    [self captureMXEvent:callStackTree
                  params:params
          diagnosticJSON:[diagnostic JSONRepresentation]];
}

- (void)didReceiveDiskWriteExceptionDiagnostic:(MXDiskWriteExceptionDiagnostic *)diagnostic
                                 callStackTree:(SentryMXCallStackTree *)callStackTree
                                timeStampBegin:(NSDate *)timeStampBegin
                                  timeStampEnd:(NSDate *)timeStampEnd
{
    NSString *totalWritesCaused =
        [self.measurementFormatter stringFromMeasurement:diagnostic.totalWritesCaused];

    NSString *exceptionValue =
        [NSString stringWithFormat:@"MXDiskWriteException totalWritesCaused:%@", totalWritesCaused];

    // Still need to figure out proper exception values and types.
    // This code is currently only there for testing with TestFlight.

    SentryMXExceptionParams *params = [[SentryMXExceptionParams alloc] init];
    params.handled = YES;
    params.level = kSentryLevelWarning;
    params.exceptionValue = exceptionValue;
    params.exceptionType = SentryMetricKitDiskWriteExceptionType;
    params.exceptionMechanism = SentryMetricKitDiskWriteExceptionMechanism;
    params.timeStampBegin = timeStampBegin;

    [self captureMXEvent:callStackTree
                  params:params
          diagnosticJSON:[diagnostic JSONRepresentation]];
}

- (void)didReceiveHangDiagnostic:(MXHangDiagnostic *)diagnostic
                   callStackTree:(SentryMXCallStackTree *)callStackTree
                  timeStampBegin:(NSDate *)timeStampBegin
                    timeStampEnd:(NSDate *)timeStampEnd
{
    NSString *hangDuration =
        [self.measurementFormatter stringFromMeasurement:diagnostic.hangDuration];

    NSString *exceptionValue = [NSString
        stringWithFormat:@"%@ hangDuration:%@", SentryMetricKitHangDiagnosticType, hangDuration];

    SentryMXExceptionParams *params = [[SentryMXExceptionParams alloc] init];
    params.handled = YES;
    params.level = kSentryLevelWarning;
    params.exceptionValue = exceptionValue;
    params.exceptionType = SentryMetricKitHangDiagnosticType;
    params.exceptionMechanism = SentryMetricKitHangDiagnosticMechanism;
    params.timeStampBegin = timeStampBegin;

    [self captureMXEvent:callStackTree params:params diagnosticJSON:[NSData data]];
}

- (void)captureMXEvent:(SentryMXCallStackTree *)callStackTree
                params:(SentryMXExceptionParams *)params
        diagnosticJSON:(NSData *)diagnosticJSON
{
    SentryEvent *event = [self createEvent:params];
    [callStackTree prepareWithEvent:event inAppLogic:self.inAppLogic handled:params.handled];

    // The crash event can be way from the past. We don't want to impact the current session.
    // Therefore we don't call captureFatalEvent.
    [self captureEvent:event withDiagnosticJSON:diagnosticJSON];
}

- (SentryEvent *)createEvent:(SentryMXExceptionParams *)params
{
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:params.level];
    event.timestamp = params.timeStampBegin;

    SentryException *exception = [[SentryException alloc] initWithValue:params.exceptionValue
                                                                   type:params.exceptionType];
    SentryMechanism *mechanism = [[SentryMechanism alloc] initWithType:params.exceptionMechanism];
    mechanism.handled = @(params.handled);
    mechanism.synthetic = @(YES);
    exception.mechanism = mechanism;
    event.exceptions = @[ exception ];

    return event;
}

- (void)captureEvent:(SentryEvent *)event withDiagnosticJSON:(NSData *)diagnosticJSON
{
    if (self.attachDiagnosticAsAttachment) {
        [SentrySDK captureEvent:event
                 withScopeBlock:^(SentryScope *_Nonnull scope) {
                     SentryAttachment *attachment =
                         [[SentryAttachment alloc] initWithData:diagnosticJSON
                                                       filename:@"MXDiagnosticPayload.json"];
                     [scope addAttachment:attachment];
                 }];
    } else {
        [SentrySDK captureEvent:event];
    }
}

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_METRIC_KIT
