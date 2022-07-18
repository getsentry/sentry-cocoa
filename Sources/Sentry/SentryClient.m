#import "SentryClient.h"
#import "NSDictionary+SentrySanitize.h"
#import "SentryAttachment.h"
#import "SentryClient+Private.h"
#import "SentryCrashDefaultMachineContextWrapper.h"
#import "SentryCrashIntegration.h"
#import "SentryCrashStackEntryMapper.h"
#import "SentryCrashWrapper.h"
#import "SentryDebugImageProvider.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryDependencyContainer.h"
#import "SentryDsn.h"
#import "SentryEnvelope.h"
#import "SentryEnvelopeItemType.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentryFileManager.h"
#import "SentryGlobalEventProcessor.h"
#import "SentryId.h"
#import "SentryInAppLogic.h"
#import "SentryInstallation.h"
#import "SentryLog.h"
#import "SentryMechanism.h"
#import "SentryMechanismMeta.h"
#import "SentryMessage.h"
#import "SentryMeta.h"
#import "SentryNSError.h"
#import "SentryOptions+Private.h"
#import "SentryOutOfMemoryTracker.h"
#import "SentrySDK+Private.h"
#import "SentryScope+Private.h"
#import "SentrySdkInfo.h"
#import "SentryStacktraceBuilder.h"
#import "SentryThreadInspector.h"
#import "SentryTraceContext.h"
#import "SentryTracer.h"
#import "SentryTransaction.h"
#import "SentryTransport.h"
#import "SentryTransportAdapter.h"
#import "SentryTransportFactory.h"
#import "SentryUser.h"
#import "SentryUserFeedback.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface
SentryClient ()

@property (nonatomic, strong) SentryTransportAdapter *transportAdapter;
@property (nonatomic, strong) SentryFileManager *fileManager;
@property (nonatomic, strong) SentryDebugImageProvider *debugImageProvider;
@property (nonatomic, strong) SentryThreadInspector *threadInspector;
@property (nonatomic, strong) id<SentryRandom> random;
@property (nonatomic, weak) id<SentryClientAttachmentProcessor> attachmentProcessor;
@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;

@end

NSString *const DropSessionLogMessage = @"Session has no release name. Won't send it.";

@implementation SentryClient

- (_Nullable instancetype)initWithOptions:(SentryOptions *)options
{
    if (self = [super init]) {
        self.options = options;

        self.debugImageProvider = [SentryDependencyContainer sharedInstance].debugImageProvider;

        SentryInAppLogic *inAppLogic =
            [[SentryInAppLogic alloc] initWithInAppIncludes:options.inAppIncludes
                                              inAppExcludes:options.inAppExcludes];
        SentryCrashStackEntryMapper *crashStackEntryMapper =
            [[SentryCrashStackEntryMapper alloc] initWithInAppLogic:inAppLogic];
        SentryStacktraceBuilder *stacktraceBuilder =
            [[SentryStacktraceBuilder alloc] initWithCrashStackEntryMapper:crashStackEntryMapper];
        id<SentryCrashMachineContextWrapper> machineContextWrapper =
            [[SentryCrashDefaultMachineContextWrapper alloc] init];

        self.threadInspector =
            [[SentryThreadInspector alloc] initWithStacktraceBuilder:stacktraceBuilder
                                            andMachineContextWrapper:machineContextWrapper];

        NSError *error = nil;

        self.fileManager = [[SentryFileManager alloc]
                   initWithOptions:self.options
            andCurrentDateProvider:[SentryDefaultCurrentDateProvider sharedInstance]
                             error:&error];
        if (nil != error) {
            [SentryLog logWithMessage:error.localizedDescription andLevel:kSentryLevelError];
            return nil;
        }

        id<SentryTransport> transport = [SentryTransportFactory initTransport:self.options
                                                            sentryFileManager:self.fileManager];

        self.transportAdapter = [[SentryTransportAdapter alloc] initWithTransport:transport
                                                                          options:options];

        self.random = [SentryDependencyContainer sharedInstance].random;

        self.crashWrapper = [SentryCrashWrapper sharedInstance];
    }
    return self;
}

/** Internal constructor for testing */
- (instancetype)initWithOptions:(SentryOptions *)options
               transportAdapter:(SentryTransportAdapter *)transportAdapter
                    fileManager:(SentryFileManager *)fileManager
                threadInspector:(SentryThreadInspector *)threadInspector
                         random:(id<SentryRandom>)random
                   crashWrapper:(SentryCrashWrapper *)crashWrapper
{
    self = [self initWithOptions:options];

    self.transportAdapter = transportAdapter;
    self.fileManager = fileManager;
    self.threadInspector = threadInspector;
    self.random = random;
    self.crashWrapper = crashWrapper;

    return self;
}

- (SentryFileManager *)fileManager
{
    return _fileManager;
}

- (SentryId *)captureMessage:(NSString *)message
{
    return [self captureMessage:message withScope:[[SentryScope alloc] init]];
}

- (SentryId *)captureMessage:(NSString *)message withScope:(SentryScope *)scope
{
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelInfo];
    event.message = [[SentryMessage alloc] initWithFormatted:message];
    return [self sendEvent:event withScope:scope alwaysAttachStacktrace:NO];
}

- (SentryId *)captureException:(NSException *)exception
{
    return [self captureException:exception withScope:[[SentryScope alloc] init]];
}

- (SentryId *)captureException:(NSException *)exception withScope:(SentryScope *)scope
{
    SentryEvent *event = [self buildExceptionEvent:exception];
    return [self sendEvent:event withScope:scope alwaysAttachStacktrace:YES];
}

- (SentryId *)captureException:(NSException *)exception
                   withSession:(SentrySession *)session
                     withScope:(SentryScope *)scope
{
    SentryEvent *event = [self buildExceptionEvent:exception];
    event = [self prepareEvent:event withScope:scope alwaysAttachStacktrace:YES];
    return [self sendEvent:event withSession:session withScope:scope];
}

- (SentryEvent *)buildExceptionEvent:(NSException *)exception
{
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelError];
    SentryException *sentryException = [[SentryException alloc] initWithValue:exception.reason
                                                                         type:exception.name];

    event.exceptions = @[ sentryException ];
    [self setUserInfo:exception.userInfo withEvent:event];
    return event;
}

- (SentryId *)captureError:(NSError *)error
{
    return [self captureError:error withScope:[[SentryScope alloc] init]];
}

- (SentryId *)captureError:(NSError *)error withScope:(SentryScope *)scope
{
    SentryEvent *event = [self buildErrorEvent:error];
    return [self sendEvent:event withScope:scope alwaysAttachStacktrace:YES];
}

- (SentryId *)captureError:(NSError *)error
               withSession:(SentrySession *)session
                 withScope:(SentryScope *)scope
{
    SentryEvent *event = [self buildErrorEvent:error];
    event = [self prepareEvent:event withScope:scope alwaysAttachStacktrace:YES];
    return [self sendEvent:event withSession:session withScope:scope];
}

- (SentryEvent *)buildErrorEvent:(NSError *)error
{
    SentryEvent *event = [[SentryEvent alloc] initWithError:error];

    NSString *exceptionValue = [NSString stringWithFormat:@"Code: %ld", (long)error.code];
    SentryException *exception = [[SentryException alloc] initWithValue:exceptionValue
                                                                   type:error.domain];

    // Sentry uses the error domain and code on the mechanism for gouping
    SentryMechanism *mechanism = [[SentryMechanism alloc] initWithType:@"NSError"];
    SentryMechanismMeta *mechanismMeta = [[SentryMechanismMeta alloc] init];
    mechanismMeta.error = [[SentryNSError alloc] initWithDomain:error.domain code:error.code];
    mechanism.meta = mechanismMeta;
    // The description of the error can be especially useful for error from swift that
    // use a simple enum.
    mechanism.desc = error.description;

    NSDictionary<NSString *, id> *userInfo = [error.userInfo sentry_sanitize];
    mechanism.data = userInfo;
    exception.mechanism = mechanism;
    event.exceptions = @[ exception ];

    // Once the UI displays the mechanism data we can the userInfo from the event.context.
    [self setUserInfo:userInfo withEvent:event];

    return event;
}

- (SentryId *)captureCrashEvent:(SentryEvent *)event withScope:(SentryScope *)scope
{
    return [self sendEvent:event withScope:scope alwaysAttachStacktrace:NO isCrashEvent:YES];
}

- (SentryId *)captureCrashEvent:(SentryEvent *)event
                    withSession:(SentrySession *)session
                      withScope:(SentryScope *)scope
{
    SentryEvent *preparedEvent = [self prepareEvent:event
                                          withScope:scope
                             alwaysAttachStacktrace:NO
                                       isCrashEvent:YES];
    return [self sendEvent:preparedEvent withSession:session withScope:scope];
}

- (SentryId *)captureEvent:(SentryEvent *)event
{
    return [self captureEvent:event withScope:[[SentryScope alloc] init]];
}

- (SentryId *)captureEvent:(SentryEvent *)event withScope:(SentryScope *)scope
{
    return [self sendEvent:event withScope:scope alwaysAttachStacktrace:NO];
}

- (SentryId *)captureEvent:(SentryEvent *)event
                  withScope:(SentryScope *)scope
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
{
    return [self sendEvent:event
                      withScope:scope
         alwaysAttachStacktrace:NO
                   isCrashEvent:NO
        additionalEnvelopeItems:additionalEnvelopeItems];
}

- (SentryId *)sendEvent:(SentryEvent *)event
                 withScope:(SentryScope *)scope
    alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
{
    return [self sendEvent:event
                     withScope:scope
        alwaysAttachStacktrace:alwaysAttachStacktrace
                  isCrashEvent:NO];
}

- (nullable SentryTraceContext *)getTraceStateWithEvent:(SentryEvent *)event
                                              withScope:(SentryScope *)scope
{
    id<SentrySpan> span;
    if ([event isKindOfClass:[SentryTransaction class]]) {
        span = [(SentryTransaction *)event trace];
    } else {
        // Even envelopes without transactions can contain the trace state, allowing Sentry to
        // eventually sample attachments belonging to a transaction.
        span = scope.span;
    }

    SentryTracer *tracer = [SentryTracer getTracer:span];
    if (tracer == nil)
        return nil;

    return [[SentryTraceContext alloc] initWithTracer:tracer scope:scope options:_options];
}

- (SentryId *)sendEvent:(SentryEvent *)event
                 withScope:(SentryScope *)scope
    alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
              isCrashEvent:(BOOL)isCrashEvent
{
    return [self sendEvent:event
                      withScope:scope
         alwaysAttachStacktrace:alwaysAttachStacktrace
                   isCrashEvent:isCrashEvent
        additionalEnvelopeItems:@[]];
}

- (SentryId *)sendEvent:(SentryEvent *)event
                  withScope:(SentryScope *)scope
     alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
               isCrashEvent:(BOOL)isCrashEvent
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
{
    SentryEvent *preparedEvent = [self prepareEvent:event
                                          withScope:scope
                             alwaysAttachStacktrace:alwaysAttachStacktrace
                                       isCrashEvent:isCrashEvent];

    if (nil != preparedEvent) {
        SentryTraceContext *traceContext = [self getTraceStateWithEvent:event withScope:scope];

        NSArray *attachments = scope.attachments;
        if (self.attachmentProcessor)
            attachments = [self.attachmentProcessor processAttachments:attachments
                                                              forEvent:preparedEvent];

        [self.transportAdapter sendEvent:preparedEvent
                            traceContext:traceContext
                             attachments:attachments
                 additionalEnvelopeItems:additionalEnvelopeItems];

        return preparedEvent.eventId;
    }

    return SentryId.empty;
}

- (SentryId *)sendEvent:(SentryEvent *)event
            withSession:(SentrySession *)session
              withScope:(SentryScope *)scope
{
    if (nil != event) {
        NSArray *attachments = scope.attachments;
        if (self.attachmentProcessor)
            attachments = [self.attachmentProcessor processAttachments:attachments forEvent:event];

        if (nil == session.releaseName || [session.releaseName length] == 0) {
            SentryTraceContext *traceContext = [self getTraceStateWithEvent:event withScope:scope];

            [SentryLog logWithMessage:DropSessionLogMessage andLevel:kSentryLevelDebug];

            [self.transportAdapter sendEvent:event
                                traceContext:traceContext
                                 attachments:attachments];
            return event.eventId;
        }

        [self.transportAdapter sendEvent:event session:session attachments:attachments];

        return event.eventId;
    } else {
        [self captureSession:session];
        return SentryId.empty;
    }
}

- (void)captureSession:(SentrySession *)session
{
    if (nil == session.releaseName || [session.releaseName length] == 0) {
        [SentryLog logWithMessage:DropSessionLogMessage andLevel:kSentryLevelDebug];
        return;
    }

    SentryEnvelopeItem *item = [[SentryEnvelopeItem alloc] initWithSession:session];
    SentryEnvelopeHeader *envelopeHeader = [[SentryEnvelopeHeader alloc] initWithId:nil
                                                                       traceContext:nil];
    SentryEnvelope *envelope = [[SentryEnvelope alloc] initWithHeader:envelopeHeader
                                                           singleItem:item];
    [self captureEnvelope:envelope];
}

- (void)captureEnvelope:(SentryEnvelope *)envelope
{
    // TODO: What is about beforeSend

    if ([self isDisabled]) {
        [self logDisabledMessage];
        return;
    }

    [self.transportAdapter sendEnvelope:envelope];
}

- (void)captureUserFeedback:(SentryUserFeedback *)userFeedback
{
    if ([self isDisabled]) {
        [self logDisabledMessage];
        return;
    }

    if ([SentryId.empty isEqual:userFeedback.eventId]) {
        [SentryLog logWithMessage:@"Capturing UserFeedback with an empty event id. Won't send it."
                         andLevel:kSentryLevelDebug];
        return;
    }

    [self.transportAdapter sendUserFeedback:userFeedback];
}

- (void)storeEnvelope:(SentryEnvelope *)envelope
{
    [self.fileManager storeEnvelope:envelope];
}

- (void)recordLostEvent:(SentryDataCategory)category reason:(SentryDiscardReason)reason
{
    [self.transportAdapter recordLostEvent:category reason:reason];
}

- (SentryEvent *_Nullable)prepareEvent:(SentryEvent *)event
                             withScope:(SentryScope *)scope
                alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
{
    return [self prepareEvent:event
                     withScope:scope
        alwaysAttachStacktrace:alwaysAttachStacktrace
                  isCrashEvent:NO];
}

- (SentryEvent *_Nullable)prepareEvent:(SentryEvent *)event
                             withScope:(SentryScope *)scope
                alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                          isCrashEvent:(BOOL)isCrashEvent
{
    NSParameterAssert(event);
    if ([self isDisabled]) {
        [self logDisabledMessage];
        return nil;
    }

    BOOL eventIsNotATransaction
        = event.type == nil || ![event.type isEqualToString:SentryEnvelopeItemTypeTransaction];

    // Transactions have their own sampleRate
    if (eventIsNotATransaction && [self isSampled:self.options.sampleRate]) {
        [SentryLog logWithMessage:@"Event got sampled, will not send the event"
                         andLevel:kSentryLevelDebug];
        [self recordLostEvent:kSentryDataCategoryError reason:kSentryDiscardReasonSampleRate];
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

    NSString *environment = self.options.environment;
    if (nil != environment && nil == event.environment) {
        // Set the environment from option to the event before Scope is applied
        event.environment = environment;
    }

    [self setSdk:event];

    // We don't want to attach debug meta and stacktraces for transactions;
    if (eventIsNotATransaction) {
        BOOL shouldAttachStacktrace = alwaysAttachStacktrace || self.options.attachStacktrace
            || (nil != event.exceptions && [event.exceptions count] > 0);

        BOOL threadsNotAttached = !(nil != event.threads && event.threads.count > 0);

        if (!isCrashEvent && shouldAttachStacktrace && threadsNotAttached) {
            event.threads = [self.threadInspector getCurrentThreads];
        }

        BOOL debugMetaNotAttached = !(nil != event.debugMeta && event.debugMeta.count > 0);
        if (!isCrashEvent && shouldAttachStacktrace && debugMetaNotAttached
            && event.threads != nil) {
            event.debugMeta = [self.debugImageProvider getDebugImagesForThreads:event.threads];
        }
    }

    event = [scope applyToEvent:event maxBreadcrumb:self.options.maxBreadcrumbs];

    if ([self isOOM:event isCrashEvent:isCrashEvent]) {
        // Remove free_memory if OOM as free_memory stems from the current run and not of
        // the time of the OOM.
        [self removeFreeMemoryFromDeviceContext:event];
    } else {
        // Store the actual free memory at the time of this event
        [self storeFreeMemoryToDeviceContext:event];
    }

    // With scope applied, before running callbacks run:
    if (nil == event.environment) {
        // We default to environment 'production' if nothing was set
        event.environment = @"production";
    }

    // Need to do this after the scope is applied cause this sets the user if there is any
    [self setUserIdIfNoUserSet:event];

    // User can't be nil as setUserIdIfNoUserSet sets it.
    if (self.options.sendDefaultPii && nil == event.user.ipAddress) {
        // Let Sentry infer the IP address from the connection.
        // Due to backward compatibility concerns, Sentry servers set the IP address to {{auto}} out
        // of the box for only Cocoa and JavaScript, which makes this toggle currently somewhat
        // useless. Still, we keep it for future compatibility reasons.
        event.user.ipAddress = @"{{auto}}";
    }

    event = [self callEventProcessors:event];
    if (event == nil) {
        [self recordLost:eventIsNotATransaction reason:kSentryDiscardReasonEventProcessor];
    }

    if (event != nil && nil != self.options.beforeSend) {
        event = self.options.beforeSend(event);

        if (event == nil) {
            [self recordLost:eventIsNotATransaction reason:kSentryDiscardReasonBeforeSend];
        }
    }

    if (isCrashEvent && nil != self.options.onCrashedLastRun && !SentrySDK.crashedLastRunCalled) {
        // We only want to call the callback once. It can occur that multiple crash events are
        // about to be sent.
        SentrySDK.crashedLastRunCalled = YES;
        self.options.onCrashedLastRun(event);
    }

    return event;
}

- (BOOL)isSampled:(NSNumber *)sampleRate
{
    if (nil == sampleRate) {
        return NO;
    }

    return [self.random nextNumber] <= sampleRate.doubleValue ? NO : YES;
}

- (BOOL)isDisabled
{
    return !self.options.enabled || nil == self.options.parsedDsn;
}

- (void)logDisabledMessage
{
    [SentryLog logWithMessage:@"SDK disabled or no DSN set. Won't do anyting."
                     andLevel:kSentryLevelDebug];
}

- (SentryEvent *_Nullable)callEventProcessors:(SentryEvent *)event
{
    SentryEvent *newEvent = event;

    for (SentryEventProcessor processor in SentryGlobalEventProcessor.shared.processors) {
        newEvent = processor(newEvent);
        if (nil == newEvent) {
            [SentryLog logWithMessage:@"SentryScope callEventProcessors: An event "
                                      @"processor decided to remove this event."
                             andLevel:kSentryLevelDebug];
            break;
        }
    }
    return newEvent;
}

- (void)setSdk:(SentryEvent *)event
{
    if (event.sdk) {
        return;
    }

    id integrations = event.extra[@"__sentry_sdk_integrations"];
    if (!integrations) {
        integrations = [NSMutableArray new];
        for (NSString *integration in self.options.enabledIntegrations) {
            // Every integration starts with "Sentry" and ends with "Integration". To keep the
            // payload of the event small we remove both.
            NSString *withoutSentry = [integration stringByReplacingOccurrencesOfString:@"Sentry"
                                                                             withString:@""];
            NSString *trimmed = [withoutSentry stringByReplacingOccurrencesOfString:@"Integration"
                                                                         withString:@""];
            [integrations addObject:trimmed];
        }
    }

    event.sdk = @{
        @"name" : SentryMeta.sdkName,
        @"version" : SentryMeta.versionString,
        @"integrations" : integrations
    };
}

- (void)setUserInfo:(NSDictionary *)userInfo withEvent:(SentryEvent *)event
{
    if (nil != event && nil != userInfo && userInfo.count > 0) {
        NSMutableDictionary *context;
        if (nil == event.context) {
            context = [[NSMutableDictionary alloc] init];
            event.context = context;
        } else {
            context = [event.context mutableCopy];
        }

        [context setValue:[userInfo sentry_sanitize] forKey:@"user info"];
    }
}

- (void)setUserIdIfNoUserSet:(SentryEvent *)event
{
    // We only want to set the id if the customer didn't set a user so we at least set something to
    // identify the user.
    if (nil == event.user) {
        SentryUser *user = [[SentryUser alloc] init];
        user.userId = [SentryInstallation id];
        event.user = user;
    }
}

- (BOOL)isOOM:(SentryEvent *)event isCrashEvent:(BOOL)isCrashEvent
{
    if (!isCrashEvent) {
        return NO;
    }

    if (nil == event.exceptions || event.exceptions.count != 1) {
        return NO;
    }

    SentryException *exception = event.exceptions[0];
    return nil != exception.mechanism &&
        [exception.mechanism.type isEqualToString:SentryOutOfMemoryMechanismType];
}

- (void)storeFreeMemoryToDeviceContext:(SentryEvent *)event
{
    [self modifyDeviceContext:event
                        block:^(NSMutableDictionary *device) {
                            device[SentryDeviceContextFreeMemoryKey] =
                                @(self.crashWrapper.freeMemory);
                        }];
}

- (void)removeFreeMemoryFromDeviceContext:(SentryEvent *)event
{
    [self modifyDeviceContext:event
                        block:^(NSMutableDictionary *device) {
                            [device removeObjectForKey:SentryDeviceContextFreeMemoryKey];
                        }];
}

- (void)modifyDeviceContext:(SentryEvent *)event block:(void (^)(NSMutableDictionary *))block
{
    if (nil == event.context || event.context.count == 0 || nil == event.context[@"device"]) {
        return;
    }

    NSMutableDictionary *context = [[NSMutableDictionary alloc] initWithDictionary:event.context];
    NSMutableDictionary *device =
        [[NSMutableDictionary alloc] initWithDictionary:context[@"device"]];
    block(device);
    context[@"device"] = device;
    event.context = context;
}

- (void)recordLost:(BOOL)eventIsNotATransaction reason:(SentryDiscardReason)reason
{
    if (eventIsNotATransaction) {
        [self recordLostEvent:kSentryDataCategoryError reason:reason];
    } else {
        [self recordLostEvent:kSentryDataCategoryTransaction reason:reason];
    }
}

@end

NS_ASSUME_NONNULL_END
