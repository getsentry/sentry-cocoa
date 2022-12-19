#import "SentryScope.h"
#import <Foundation/Foundation.h>
#import <SentryDebugMeta.h>
#import <SentryDependencyContainer.h>
#import <SentryEvent.h>
#import <SentryException.h>
#import <SentryFrame.h>
#import <SentryHexAddressFormatter.h>
#import <SentryMechanism.h>
#import <SentryMetricKitIntegration.h>
#import <SentrySDK+Private.h>
#import <SentryStacktrace.h>
#import <SentryThread.h>

#if SENTRY_HAS_METRIC_KIT

/**
 * We need to check if MetricKit is available for compatibility on iOS 12 and below. As there are no
 * compiler directives for iOS versions we use __has_include.
 */
#    if __has_include(<MetricKit/MetricKit.h>)
#        import <MetricKit/MetricKit.h>
#    endif

NS_ASSUME_NONNULL_BEGIN

@interface
SentryMetricKitIntegration ()

@property (nonatomic, strong, nullable) SentryMXManager *metricKitManager;
@property (nonatomic, strong) NSMeasurementFormatter *measurementFormatter;

@end

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

    [self captureMXEvent:callStackTree
          exceptionValue:exceptionValue
           exceptionType:@"MXCrashDiagnostic"
                 handled:NO
          withScopeBlock:^(SentryScope *_Nonnull scope) {
              [scope clearBreadcrumbs];
              if (diagnostic.virtualMemoryRegionInfo) {
                  [scope setContextValue:@ {
                      @"virtualMemoryRegionInfo" : diagnostic.virtualMemoryRegionInfo
                  }
                                  forKey:@"MetricKit"];
              }
          }];
}

- (void)didReceiveCpuExceptionDiagnostic:(MXCPUExceptionDiagnostic *)diagnostic
                           callStackTree:(SentryMXCallStackTree *)callStackTree
                          timeStampBegin:(NSDate *)timeStampBegin
                            timeStampEnd:(NSDate *)timeStampEnd
{
    NSString *totalCPUTime =
        [self.measurementFormatter stringFromMeasurement:diagnostic.totalCPUTime];
    NSString *totalSampledTime =
        [self.measurementFormatter stringFromMeasurement:diagnostic.totalSampledTime];

    NSString *exceptionValue =
        [NSString stringWithFormat:@"MXCPUException totalCPUTime:%@ totalSampledTime:%@",
                  totalCPUTime, totalSampledTime];

    // Still need to figure out proper exception values and types.
    // This code is currently only there for testing with TestFlight.
    [self captureMXEvent:callStackTree
          exceptionValue:exceptionValue
           exceptionType:@"MXCPUException"
                 handled:YES
          withScopeBlock:^(SentryScope *_Nonnull scope) { [scope clearBreadcrumbs]; }];
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
    [self captureMXEvent:callStackTree
          exceptionValue:exceptionValue
           exceptionType:@"MXDiskWriteException"
                 handled:YES
          withScopeBlock:^(SentryScope *_Nonnull scope) { [scope clearBreadcrumbs]; }];
}

- (void)captureMXEvent:(SentryMXCallStackTree *)callStackTree
        exceptionValue:(NSString *)exceptionValue
         exceptionType:(NSString *)exceptionType
               handled:(BOOL)handled
        withScopeBlock:(void (^)(SentryScope *))block
{
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelFatal];

    SentryException *exception = [[SentryException alloc] initWithValue:exceptionValue
                                                                   type:exceptionType];
    SentryMechanism *mechanism = [[SentryMechanism alloc] initWithType:exceptionType];
    mechanism.handled = @(handled);
    exception.mechanism = mechanism;
    event.exceptions = @[ exception ];

    event.threads = [self convertToSentryThreads:callStackTree];
    event.debugMeta = [self extractDebugMeta:callStackTree.callStacks];

    // The crash event can be way from the past. We don't want to impact the current session.
    // Therefore we don't call captureCrashEvent.
    [SentrySDK captureEvent:event withScopeBlock:block];
}

- (NSArray<SentryThread *> *)convertToSentryThreads:(SentryMXCallStackTree *)callStackTree
{
    NSUInteger i = 0;
    NSMutableArray<SentryThread *> *threads = [NSMutableArray array];
    for (SentryMXCallStack *callStack in callStackTree.callStacks) {

        NSMutableArray<SentryFrame *> *frames = [NSMutableArray array];

        NSEnumerator<SentryMXFrame *> *frameEnumerator
            = callStack.flattenedRootFrames.objectEnumerator;
        // The MXFrames are in reversed order when callStackPerThread is true. The Apple docs don't
        // state that. This is an assumption based on observing MetricKit data.
        if (callStackTree.callStackPerThread) {
            frameEnumerator = [callStack.flattenedRootFrames reverseObjectEnumerator];
        }

        for (SentryMXFrame *mxFrame in frameEnumerator) {
            SentryFrame *frame = [[SentryFrame alloc] init];
            frame.package = mxFrame.binaryName;
            frame.instructionAddress = sentry_formatHexAddress(@(mxFrame.address));
            NSNumber *imageAddress = @(mxFrame.address - mxFrame.offsetIntoBinaryTextSegment);
            frame.imageAddress = sentry_formatHexAddress(imageAddress);

            [frames addObject:frame];
        }

        SentryStacktrace *stacktrace = [[SentryStacktrace alloc] initWithFrames:frames
                                                                      registers:@{}];

        SentryThread *thread = [[SentryThread alloc] initWithThreadId:@(i)];
        thread.stacktrace = stacktrace;

        [threads addObject:thread];

        i++;
    }

    return threads;
}

/**
 * We must extract the debug images from the MetricKit stacktraces as the image addresses change
 * when you restart the app.
 */
- (NSArray<SentryDebugMeta *> *)extractDebugMeta:(NSArray<SentryMXCallStack *> *)callStacks
{
    NSMutableDictionary<NSString *, SentryDebugMeta *> *debugMetas =
        [NSMutableDictionary dictionary];
    for (SentryMXCallStack *callStack in callStacks) {

        for (SentryMXFrame *mxFrame in callStack.flattenedRootFrames) {

            NSString *binaryUUID = [mxFrame.binaryUUID UUIDString];
            if (debugMetas[binaryUUID]) {
                continue;
            }

            SentryDebugMeta *debugMeta = [[SentryDebugMeta alloc] init];
            debugMeta.type = @"apple";
            debugMeta.uuid = binaryUUID;
            debugMeta.name = mxFrame.binaryName;

            NSNumber *imageAddress = @(mxFrame.address - mxFrame.offsetIntoBinaryTextSegment);
            debugMeta.imageAddress = sentry_formatHexAddress(imageAddress);

            debugMetas[debugMeta.uuid] = debugMeta;
        }
    }

    return [debugMetas allValues];
}

@end

NS_ASSUME_NONNULL_END

#endif
