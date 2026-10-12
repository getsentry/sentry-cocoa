#import "SentryClient.h"
#import "NSMutableDictionary+Sentry.h"
#import "SentryAttachment.h"
#import "SentryClient+Attachments.h"
#import "SentryClient+ErrorEvents.h"
#import "SentryClient+EventCapture.h"
#import "SentryClient+EventContext.h"
#import "SentryClient+EventPreparation.h"
#import "SentryClient+EventSending.h"
#import "SentryClient+Private.h"
#import "SentryClient+ReplayAndFeedback.h"
#import "SentryClient+SessionsAndCrashes.h"
#import "SentryClient+Telemetry.h"
#import "SentryCrashStackEntryMapper.h"
#import "SentryDefaultTelemetryProcessorTransport.h"
#import "SentryDefaultThreadInspector.h"
#import "SentryDeviceContextKeys.h"
#import "SentryEvent+Private.h"
#import "SentryException.h"
#import "SentryInternalDefines.h"
#import "SentryLogC.h"
#import "SentryMechanism.h"
#import "SentryMechanismContext.h"
#import "SentryMessage.h"
#import "SentryMsgPackSerializer.h"
#import "SentryNSError.h"
#import "SentrySDK+Private.h"
#import "SentrySanitizerUtils.h"
#import "SentryScope+Private.h"
#import "SentryScope+PrivateSwift.h"
#import "SentrySerialization.h"
#import "SentryStacktraceBuilder.h"
#import "SentrySwift.h"
#import "SentryTraceContext+Private.h"
#import "SentryTraceContext.h"
#import "SentryTracer.h"
#import "SentryTransaction+Private.h"
#import "SentryTransportFactory.h"
#import "SentryUser.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@protocol SentryEventContextEnricher;

@interface SentryClientInternal ()

@property (nonatomic, strong) SentryTransportAdapter *transportAdapter;
@property (nonatomic, strong) SentryDebugImageProvider *debugImageProvider;
@property (nonatomic, strong) id<SentryRandomProtocol> random;
@property (nonatomic, strong) NSLocale *locale;
@property (nonatomic, strong) NSTimeZone *timezone;
@property (nonatomic, strong) id<SentryEventContextEnricher> eventContextEnricher;

@end

NSString *const DropSessionLogMessage = @"Session has no release name. Won't send it.";

@implementation SentryClientInternal

- (_Nullable instancetype)initWithOptions:(SentryOptions *)options
{
    [SentryClientEventContextLinker class];
    [SentryClientErrorEventsLinker class];
    [SentryClientTelemetryLinker class];
    [SentryClientReplayAndFeedbackLinker class];
    [SentryClientAttachmentsLinker class];
    [SentryClientEventSendingLinker class];
    [SentryClientEventPreparationLinker class];
    [SentryClientSessionsAndCrashesLinker class];
    [SentryClientEventCaptureLinker class];

    SentryDependencyContainer *dependencies = SentryDependencyContainer.sharedInstance;

    NSError *error;
    SentryFileManager *fileManager =
        [[SentryFileManager alloc] initWithOptions:options
                                      dateProvider:dependencies.dateProvider
                              dispatchQueueWrapper:dependencies.dispatchQueueWrapper
                                             error:&error];
    if (error != nil) {
        SENTRY_LOG_FATAL(@"Failed to initialize file system: %@", error.localizedDescription);
        return nil;
    }

    NSArray<id<SentryTransport>> *transports =
        [SentryTransportFactory initTransports:options
                                  dateProvider:dependencies.dateProvider
                             sentryFileManager:fileManager
                                    rateLimits:dependencies.rateLimits
                                  reachability:dependencies.reachability];

    SentryTransportAdapter *transportAdapter =
        [[SentryTransportAdapter alloc] initWithTransports:transports options:options];

    SentryDefaultThreadInspector *threadInspector =
        [[SentryDefaultThreadInspector alloc] initWithOptions:options];

    return [self initWithOptions:options
                    dateProvider:dependencies.dateProvider
                transportAdapter:transportAdapter
                     fileManager:fileManager
                 threadInspector:threadInspector
              debugImageProvider:dependencies.debugImageProvider
                          random:dependencies.random
                          locale:[NSLocale autoupdatingCurrentLocale]
                        timezone:[NSCalendar autoupdatingCurrentCalendar].timeZone
            eventContextEnricher:dependencies.eventContextEnricher
                binaryImageCache:dependencies.binaryImageCache
            dispatchQueueWrapper:dependencies.dispatchQueueWrapper
             currentScopeStorage:dependencies.currentScopeStorage];
}

- (instancetype)initWithOptions:(SentryOptions *)options
                   dateProvider:(id<SentryCurrentDateProvider>)dateProvider
               transportAdapter:(SentryTransportAdapter *)transportAdapter
                    fileManager:(SentryFileManager *)fileManager
                threadInspector:(SentryDefaultThreadInspector *)threadInspector
             debugImageProvider:(SentryDebugImageProvider *)debugImageProvider
                         random:(id<SentryRandomProtocol>)random
                         locale:(NSLocale *)locale
                       timezone:(NSTimeZone *)timezone
           eventContextEnricher:(id<SentryEventContextEnricher>)eventContextEnricher
               binaryImageCache:(SentryBinaryImageCache *)binaryImageCache
           dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
{
    return [self initWithOptions:options
                    dateProvider:dateProvider
                transportAdapter:transportAdapter
                     fileManager:fileManager
                 threadInspector:threadInspector
              debugImageProvider:debugImageProvider
                          random:random
                          locale:locale
                        timezone:timezone
            eventContextEnricher:eventContextEnricher
                binaryImageCache:binaryImageCache
            dispatchQueueWrapper:dispatchQueueWrapper
             currentScopeStorage:SentryDependencyContainer.sharedInstance.currentScopeStorage];
}

- (instancetype)initWithOptions:(SentryOptions *)options
                   dateProvider:(id<SentryCurrentDateProvider>)dateProvider
               transportAdapter:(SentryTransportAdapter *)transportAdapter
                    fileManager:(SentryFileManager *)fileManager
                threadInspector:(SentryDefaultThreadInspector *)threadInspector
             debugImageProvider:(SentryDebugImageProvider *)debugImageProvider
                         random:(id<SentryRandomProtocol>)random
                         locale:(NSLocale *)locale
                       timezone:(NSTimeZone *)timezone
           eventContextEnricher:(id<SentryEventContextEnricher>)eventContextEnricher
               binaryImageCache:(SentryBinaryImageCache *)binaryImageCache
           dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
            currentScopeStorage:(SentryCurrentScopeStorage *)currentScopeStorage
{
    if (self = [super init]) {
        _isEnabled = YES;
        self.options = options;
        self.transportAdapter = transportAdapter;
        self.fileManager = fileManager;
        self.threadInspector = threadInspector;
        self.random = random;
        self.debugImageProvider = debugImageProvider;
        self.locale = locale;
        self.timezone = timezone;
        self.attachmentProcessors = [[NSMutableArray alloc] init];
        self.eventContextEnricher = eventContextEnricher;
        self.dispatchQueueWrapper = dispatchQueueWrapper;
        self.currentScopeStorage = currentScopeStorage;

        self.telemetryProcessor = [SentryTelemetryProcessorFactory
            getProcessorWithTransport:[[SentryDefaultTelemetryProcessorTransport alloc]
                                          initWithTransportAdapter:transportAdapter]
                         dependencies:SentryDependencyContainer.sharedInstance];

#if SDK_V10
        BOOL shouldAddDefaultUserId = options.dataCollectionObjC.userInfo;
#else
        BOOL shouldAddDefaultUserId = options.sendDefaultPii;
#endif // SDK_V10
        self.logScopeApplier =
            [[SentryDefaultLogScopeApplier alloc] initWithEnvironment:options.environment
                                                          releaseName:options.releaseName
                                                   cacheDirectoryPath:options.cacheDirectoryPath
                                               shouldAddDefaultUserId:shouldAddDefaultUserId];

        [binaryImageCache start:options.debug];

        // The SDK stores the installationID in a file. The first call requires file IO. To avoid
        // executing this on the main thread, we cache the installationID async here.
        [SentryInstallation cacheIDAsyncWithCacheDirectoryPath:options.cacheDirectoryPath];

        [fileManager deleteOldEnvelopeItems];
    }
    return self;
}

- (void)setOptionsInternal:(SentryOptions *)optionsInternal
{
    self.options = optionsInternal;
}

- (NSObject *)getOptions
{
    return self.options;
}

- (nullable SentryTraceContext *)getTraceStateWithEvent:(SentryEvent *)event
                                              withScope:(SentryScope *)scope
                                           currentScope:(nullable SentryScope *)currentScope
{
    id<SentrySpan> currentScopeSpan = currentScope.span;
    id<SentrySpan> span;
    if ([event isKindOfClass:[SentryTransaction class]]) {
        span = [(SentryTransaction *)event trace];
    } else {
        // Even envelopes without transactions can contain the trace state, allowing Sentry to
        // eventually sample attachments belonging to a transaction.
        span = currentScopeSpan ?: scope.span;
    }

    SentryTracer *tracer = [SentryTracer getTracer:span];
    if (tracer != nil) {
        return [[SentryTraceContext alloc] initWithTracer:tracer scope:scope options:_options];
    }

    if (event.error || event.exceptions.count > 0) {
        SentryId *traceId = currentScopeSpan.traceId ?: scope.propagationContext.traceId;
        return [[SentryTraceContext alloc] initWithTraceId:traceId
                                                   options:self.options
                                                  replayId:scope.replayId];
    }

    return nil;
}

- (void)captureEnvelope:(SentryEnvelope *)envelope
{
    if ([self isDisabled]) {
        [self logDisabledMessage];
        return;
    }

    [self.transportAdapter sendEnvelope:envelope];
}

- (void)captureFeedback:(SentryFeedback *)feedback withScope:(SentryScope *)scope
{
    SentryScope *cs = [self.currentScopeStorage scope];
    [self captureSerializedFeedback:[feedback serialize]
                        withEventId:feedback.eventId.sentryIdString
                        attachments:[feedback attachmentsForEnvelope]
                              scope:scope
                       currentScope:cs];
}

- (void)storeEnvelope:(SentryEnvelope *)envelope
{
    [self.fileManager storeEnvelope:envelope];
}

- (void)recordLostEvent:(SentryDataCategory)category reason:(SentryDiscardReason)reason
{
    [self.transportAdapter recordLostEvent:category reason:reason];
}

- (void)recordLostEvent:(SentryDataCategory)category
                 reason:(SentryDiscardReason)reason
               quantity:(NSUInteger)quantity
{
    [self.transportAdapter recordLostEvent:category reason:reason quantity:quantity];
}

- (void)flush:(NSTimeInterval)timeout
{
    NSTimeInterval forwardingTelemetryDataDuration = [self.telemetryProcessor forwardTelemetryData];
    // Calculate remaining timeout for transport flush.
    // We subtract the time already spent capturing logs to respect the overall timeout.
    // If log capture took longer than the timeout, we use 0.0 which will still trigger
    // sending events but won't block waiting for completion.
    NSTimeInterval remainingTimeout = fmax(0.0, timeout - forwardingTelemetryDataDuration);
    [self.transportAdapter flush:remainingTimeout];
}

- (void)close
{
    _isEnabled = NO;
    [self flush:self.options.shutdownTimeInterval];
    SENTRY_LOG_DEBUG(@"Closed the Client.");
}

- (SentryEvent *_Nullable)prepareEvent:(SentryEvent *_Nullable)event
                             withScope:(SentryScope *)scope
                alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                          isFatalEvent:(BOOL)isFatalEvent
                          currentScope:(SentryScope *_Nullable)currentScope
                                  hint:(SentryHint *)hint
{
    NSParameterAssert(event);
    if (event == nil) {
        return nil;
    }

    if ([self isDisabled]) {
        [self logDisabledMessage];
        return nil;
    }

    BOOL eventIsNotATransaction
        = event.type == nil || ![event.type isEqualToString:SentryEnvelopeItemTypes.transaction];
    BOOL eventIsNotReplay
        = event.type == nil || ![event.type isEqualToString:SentryEnvelopeItemTypes.replayVideo];
    BOOL eventIsNotUserFeedback
        = event.type == nil || ![event.type isEqualToString:SentryEnvelopeItemTypes.feedback];

    // Transactions and replays have their own sampleRate
    if (eventIsNotATransaction && eventIsNotReplay && eventIsNotUserFeedback &&
        [self isSampled:self.options.sampleRate]) {
        SENTRY_LOG_DEBUG(@"Event got sampled, will not send the event");
        [self recordLostEvent:SentryDataCategoryError reason:SentryDiscardReasonSampleRate];
        return nil;
    }

    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    if (nil != infoDict && nil == event.dist) {
        event.dist = infoDict[@"CFBundleVersion"];
    }

    // Use the values from SentryOptions as a fallback,
    // in case not yet set directly in the event nor in the scope:
    NSString *releaseName = self.options.releaseName;
    if (nil == event.releaseName && nil != releaseName) {
        // If no release was already set (i.e: crashed on an older version) use
        // current release name
        event.releaseName = releaseName;
    }

    NSString *dist = self.options.dist;
    if (nil != dist) {
        event.dist = dist;
    }

    [self setSdk:SENTRY_UNWRAP_NULLABLE(SentryEvent, event)];

    // Fatal events and events flagged as coming from an earlier app run, such as MetricKit
    // diagnostics delivered on a later launch, describe a process that no longer exists. The
    // current scope, the running app's state and mutable device data don't apply to them.
    BOOL isFromEarlierAppRun = isFatalEvent || event.isFromEarlierAppRun;

    // We don't want to attach debug meta and stacktraces for transactions, replays or user
    // feedback.
    if (eventIsNotATransaction && eventIsNotReplay && eventIsNotUserFeedback) {
        BOOL shouldAttachStacktrace = alwaysAttachStacktrace || self.options.attachStacktrace
            || (nil != event.exceptions && [event.exceptions count] > 0);

#if SENTRY_HAS_METRIC_KIT
        // MetricKit diagnostics describe past events. Current threads and images cannot fill in
        // missing diagnostic data, including when the call stack tree could not be decoded.
        shouldAttachStacktrace = shouldAttachStacktrace && ![event isMetricKitEvent];
#endif

        BOOL threadsNotAttached = !(nil != event.threads && event.threads.count > 0);

        if (!isFromEarlierAppRun && shouldAttachStacktrace && threadsNotAttached) {
            BOOL attachAll = event.attachAllThreadsOverride != nil
                ? event.attachAllThreadsOverride.boolValue
                : self.options.attachAllThreads;

            if (attachAll) {
                event.threads = [self.threadInspector getCurrentThreadsWithStackTrace];
            } else {
                event.threads = [self.threadInspector getCurrentThreads];
            }
        }

        BOOL debugMetaNotAttached = !(nil != event.debugMeta && event.debugMeta.count > 0);
        if (!isFromEarlierAppRun && shouldAttachStacktrace && debugMetaNotAttached
            && event.threads != nil) {
            event.debugMeta = [self.debugImageProvider
                getDebugImagesFromCacheForThreads:SENTRY_UNWRAP_NULLABLE(
                                                      NSArray<SentryThread *>, event.threads)];
        }
    }

#if SENTRY_HAS_UIKIT
    if (!isFromEarlierAppRun && eventIsNotReplay) {
        NSDictionary *currentContext = event.context ?: @{ };
        event.context = [self.eventContextEnricher enrichWithAppState:currentContext];
    }
#endif

    // Applying the current scope to an event from an earlier app run would attach data of the
    // current process.
    if (!isFromEarlierAppRun) {
        // Unwrapping the event because we assume that the event will be returned
        event = SENTRY_UNWRAP_NULLABLE(
            SentryEvent, [scope applyToEvent:event maxBreadcrumb:self.options.maxBreadcrumbs]);
    }

    if (!isFromEarlierAppRun && currentScope != nil && event != nil) {
        [currentScope overlayOnEvent:SENTRY_UNWRAP_NULLABLE(SentryEvent, event)
                       maxBreadcrumb:self.options.maxBreadcrumbs];
    }

    if (!eventIsNotReplay) {
        event.breadcrumbs = nil;
    }

    if ([self isWatchdogTermination:SENTRY_UNWRAP_NULLABLE(SentryEvent, event)
                       isFatalEvent:isFatalEvent]) {
        // Remove some mutable properties from the device/app contexts which are no longer
        // applicable
        [self removeExtraDeviceContextFromEvent:SENTRY_UNWRAP_NULLABLE(SentryEvent, event)];
    } else if (!isFromEarlierAppRun) {
        // Store the current free memory battery level and more mutable properties,
        // at the time of this event, but not for events from an earlier app run as the current
        // data isn't guaranteed to be the same as when they happened.
        [self applyExtraDeviceContextToEvent:SENTRY_UNWRAP_NULLABLE(SentryEvent, event)];
        [self applyCultureContextToEvent:SENTRY_UNWRAP_NULLABLE(SentryEvent, event)];
#if SENTRY_HAS_UIKIT
        [self applyCurrentViewNamesToEventContext:SENTRY_UNWRAP_NULLABLE(SentryEvent, event)
                                        withScope:scope];
#endif // SENTRY_HAS_UIKIT
    }

    // With scope applied, before running callbacks run:
    if (event.environment == nil) {
        // We default to environment 'production' if nothing was set
        event.environment = self.options.environment;
    }

    // Need to do this after the scope is applied cause this sets the user if there is any
    [self setUserIdIfNoUserSet:SENTRY_UNWRAP_NULLABLE(SentryEvent, event)];

    BOOL eventIsATransaction
        = event.type != nil && [event.type isEqualToString:SentryEnvelopeItemTypes.transaction];
    BOOL eventIsATransactionClass
        = eventIsATransaction && [event isKindOfClass:[SentryTransaction class]];

    NSUInteger currentSpanCount;
    if (eventIsATransactionClass) {
        SentryTransaction *transaction = (SentryTransaction *)event;
        currentSpanCount = transaction.spans.count;
    } else {
        currentSpanCount = 0;
    }

    if (event != nil && eventIsATransaction && self.options.beforeSendSpan != nil) {
        SentryTransaction *transaction = (SentryTransaction *)event;
        NSMutableArray<id<SentrySpan>> *processedSpans = [NSMutableArray array];
        for (id<SentrySpan> span in transaction.spans) {
            id<SentrySpan> processedSpan = self.options.beforeSendSpan(span);
            if (processedSpan) {
                [processedSpans addObject:processedSpan];
            }
        }
        transaction.spans = processedSpans;

        if (eventIsATransactionClass) {
            [self recordPartiallyDroppedSpans:transaction
                                   withReason:SentryDiscardReasonBeforeSend
                         withCurrentSpanCount:&currentSpanCount];
        }
    }

#if SDK_V10
    if (eventIsATransactionClass && event != nil) {
        if (self.options.beforeSendTransaction != nil) {
            event = self.options.beforeSendTransaction((SentryTransaction *)event, hint);
        }
        if (event == nil) {
            [self recordLost:NO reason:SentryDiscardReasonBeforeSend];
            // We dropped the whole transaction, the dropped count includes all child spans + 1
            // root span
            [self recordLostSpanWithReason:SentryDiscardReasonBeforeSend
                                  quantity:currentSpanCount + 1];
        } else if ([event isKindOfClass:[SentryTransaction class]]) {
            [self recordPartiallyDroppedSpans:(SentryTransaction *)event
                                   withReason:SentryDiscardReasonBeforeSend
                         withCurrentSpanCount:&currentSpanCount];
        }
    } else if (eventIsNotUserFeedback && !eventIsATransaction && event != nil) {
        if (self.options.beforeSendWithHint != nil) {
            event
                = self.options.beforeSendWithHint(SENTRY_UNWRAP_NULLABLE(SentryEvent, event), hint);
        } else if (self.options.beforeSend != nil) {
            event = self.options.beforeSend(SENTRY_UNWRAP_NULLABLE(SentryEvent, event));
        }
        if (event == nil) {
            [self recordLost:YES reason:SentryDiscardReasonBeforeSend];
        }
    }
#else
    if (eventIsNotUserFeedback && event != nil) {
        if (self.options.beforeSendWithHint != nil) {
            event
                = self.options.beforeSendWithHint(SENTRY_UNWRAP_NULLABLE(SentryEvent, event), hint);
        } else if (self.options.beforeSend != nil) {
            event = self.options.beforeSend(SENTRY_UNWRAP_NULLABLE(SentryEvent, event));
        }
        if (event == nil) {
            [self recordLost:eventIsNotATransaction reason:SentryDiscardReasonBeforeSend];
            if (eventIsATransaction) {
                // We dropped the whole transaction, the dropped count includes all child spans + 1
                // root span
                [self recordLostSpanWithReason:SentryDiscardReasonBeforeSend
                                      quantity:currentSpanCount + 1];
            }
        } else {
            if ([event isKindOfClass:[SentryTransaction class]]) {
                [self recordPartiallyDroppedSpans:(SentryTransaction *)event
                                       withReason:SentryDiscardReasonBeforeSend
                             withCurrentSpanCount:&currentSpanCount];
            }
        }
    }
#endif // SDK_V10

    if (event != nil) {
        // if the event is dropped by beforeSend we should not execute event processors as they
        // might trigger e.g. unnecessary replay capture
        event = [self callEventProcessors:SENTRY_UNWRAP_NULLABLE(SentryEvent, event)];
        if (event == nil) {
            [self recordLost:eventIsNotATransaction reason:SentryDiscardReasonEventProcessor];
            if (eventIsATransaction) {
                // We dropped the whole transaction, the dropped count includes all child spans + 1
                // root span
                [self recordLostSpanWithReason:SentryDiscardReasonEventProcessor
                                      quantity:currentSpanCount + 1];
            }
        } else {
            if ([event isKindOfClass:[SentryTransaction class]]) {
                [self recordPartiallyDroppedSpans:(SentryTransaction *)event
                                       withReason:SentryDiscardReasonEventProcessor
                             withCurrentSpanCount:&currentSpanCount];
            }
        }
    }

    if (event != nil && isFatalEvent && !SentrySDKInternal.lastRunStatusCalled) {
        // We only want to call the callbacks once. It can occur that multiple crash events are
        // about to be sent.
        SentrySDKInternal.lastRunStatusCalled = YES;

#if !SDK_V10
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if (nil != self.options.onCrashedLastRun) {
            self.options.onCrashedLastRun(SENTRY_UNWRAP_NULLABLE(SentryEvent, event));
        }
#    pragma clang diagnostic pop
#endif

        if (nil != self.options.onLastRunStatusDetermined) {
            self.options.onLastRunStatusDetermined(
                SentryLastRunStatusDidCrash, SENTRY_UNWRAP_NULLABLE(SentryEvent, event));
        }
    }

    return event;
}

- (BOOL)isDisabled
{
    return !_isEnabled || !self.options.enabled || nil == self.options.parsedDsn;
}

- (void)logDisabledMessage
{
    SENTRY_LOG_DEBUG(@"SDK disabled or no DSN set. Won't do anything.");
}

- (void)setUserInfo:(NSDictionary *_Nullable)userInfo withEvent:(SentryEvent *_Nullable)event
{
    if (nil != event && nil != userInfo && userInfo.count > 0) {
        NSMutableDictionary *context;
        if (event.context == nil) {
            context = [[NSMutableDictionary alloc] init];
            event.context = context;
        } else {
            context = [event.context mutableCopy];
        }

        [context setValue:sentry_sanitize_dictionary(userInfo) forKey:@"user info"];
    }
}

@end

NS_ASSUME_NONNULL_END
