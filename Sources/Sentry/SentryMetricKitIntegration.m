#import <Foundation/Foundation.h>
#import <MetricKit/MetricKit.h>
#import <SentryDependencyContainer.h>
#import <SentryEvent.h>
#import <SentryException.h>
#import <SentryFrame.h>
#import <SentryHexAddressFormatter.h>
#import <SentryMechanism.h>
#import <SentryMetricKitIntegration.h>
#import <SentrySDK+Private.h>
#import <SentryStacktrace.h>
#import <SentrySwift.h>
#import <SentryThread.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryMetricKitIntegration ()

@property (nonatomic, strong) SentryMetricKitManager *metricKitManager;

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
}

/**
 * Only for testing. We need to publish the iOS-Swift sample app to TestFlight for properly testing
 * this. We easily get MXCrashDiagnostic and so we can use them for validating symbolication. We
 * don't plan on releasing this. Instead, we are going to remove this code before releasing.
 */
- (void)didReceiveCrashDiagnosticWithCrashDiagnostic:(MXCrashDiagnostic *)crashDiagnostic
                                       callStackTree:(SentryMXCallStackTree *)callStackTree
{

    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelFatal];

    SentryException *exception =
        [[SentryException alloc] initWithValue:crashDiagnostic.terminationReason
                                          type:@"MXCrashDiagnostic"];
    SentryMechanism *mechanism = [[SentryMechanism alloc] initWithType:@"MXCrashDiagnostic"];
    mechanism.handled = @(NO);
    exception.mechanism = mechanism;
    event.exceptions = @[ exception ];

    NSUInteger i = 0;
    NSMutableArray<SentryThread *> *threads = [NSMutableArray array];
    for (SentryMXCallStack *callStack in callStackTree.callStacks) {

        NSMutableArray<SentryFrame *> *frames = [NSMutableArray array];
        for (SentryMXFrame *mxFrame in callStack.flattenedRootFrames) {

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

    event.threads = threads;

    [SentrySDK captureEvent:event];
}

@end

NS_ASSUME_NONNULL_END
