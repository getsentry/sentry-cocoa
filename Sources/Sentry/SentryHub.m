#import "SentryHub.h"
#import "SentryClient.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryIntegrationProtocol.h"
#import "SentrySDK.h"
#import "SentryLog.h"
#import "SentryCrash.h"
#import "SentryFileManager.h"

@interface SentryHub()

@property (nonatomic, strong) SentryClient *_Nullable client;
@property (nonatomic, strong) SentryScope *_Nullable scope;

@end

@implementation SentryHub {
    NSObject *_sessionLock;
}

@synthesize scope;

- (instancetype)initWithClient:(SentryClient *_Nullable)client andScope:(SentryScope *_Nullable)scope {
    if (self = [super init]) {
        self.scope = scope;
        [self bindClient:client];
        _sessionLock = [[NSObject alloc] init];
        [self closeCachedSession];
    }
    return self;
}

- (void)startSession {
    SentrySession *lastSession = nil;
    SentryScope *scope = [self getScope];
    @synchronized (_sessionLock) {
        if (nil != _session) {
            lastSession = _session;
        }
        _session = [[SentrySession alloc] init];
        [scope applyToSession:_session];
        [self storeCurrentSession:_session];
        // TODO: Capture outside the lock. Not the reference in the scope.
        [self captureSession:_session];
    }
    [lastSession endSession];
    [self captureSession:lastSession];
}

- (void)endSession {
    SentrySession *currentSession = nil;
    @synchronized (_sessionLock) {
        currentSession = _session;
        _session = nil;
        [self deleteCurrentSession];
    }
    
    if (nil == currentSession) {
        // TODO: log
        return;
    }

    [currentSession endSession];
    [self captureSession:currentSession];
}

- (void)endSessionWithTimestamp:(NSDate*)timestamp {
    SentrySession *currentSession = nil;
    @synchronized (_sessionLock) {
        currentSession = _session;
        _session = nil;
        [self deleteCurrentSession];
    }
    
    if (nil == currentSession) {
        // TODO: log
        return;
    }

    [currentSession endSessionWithTimestamp:timestamp];
    [self captureSession:currentSession];
}

- (void)storeCurrentSession:(SentrySession *)session {
    [[[self getClient] fileManager] storeCurrentSession:session];
}

- (void)deleteCurrentSession {
    [[[self getClient] fileManager] deleteCurrentSession];
}

- (void)closeCachedSession {
    SentrySession *session = [[[self getClient] fileManager] readCurrentSession];
    if (nil != session) {
        SentryClient *client = [self getClient];
        if (nil != session && nil != client) { // Make sure there's a client bound.
            NSDate *timestamp = [NSDate date];
            if (SentryCrash.sharedInstance.crashedLastLaunch) {
                [session crashedSession];
            }
            [session endSessionWithTimestamp:timestamp];
            [self deleteCurrentSession];
            [client captureSession:session];
        }
    }
}

- (void)captureSession:(SentrySession *)session {
    if (nil != session) {
        SentryClient *client = [self getClient];
        [client captureSession:session];
    }
}

- (void)incrementSessionErrors {
    @synchronized (_sessionLock) {
        [_session incrementErrors];
        [self storeCurrentSession:_session];
    }
}

- (NSString *_Nullable)captureEvent:(SentryEvent *)event withScope:(SentryScope *_Nullable)scope {
    SentryClient *client = [self getClient];
    if (nil != client) {
        return [client captureEvent:event withScope:scope];
    }
    return nil;
}

- (NSString *_Nullable)captureMessage:(NSString *)message withScope:(SentryScope *_Nullable)scope {
    SentryClient *client = [self getClient];
    if (nil != client) {
        return [client captureMessage:message withScope:scope];
    }
    return nil;
}

- (NSString *_Nullable)captureError:(NSError *)error withScope:(SentryScope *_Nullable)scope {
    [self incrementSessionErrors];
    SentryClient *client = [self getClient];
    if (nil != client) {
        return [client captureError:error withScope:scope];
    }
    return nil;
}

- (NSString *_Nullable)captureException:(NSException *)exception withScope:(SentryScope *_Nullable)scope {
    [self incrementSessionErrors];
    SentryClient *client = [self getClient];
    if (nil != client) {
        return [client captureException:exception withScope:scope];
    }
    return nil;
}

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb {
    SentryBeforeBreadcrumbCallback callback = [[[self client] options] beforeBreadcrumb];
    if (nil != callback) {
        crumb = callback(crumb);
    }
    if (nil == crumb) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Discarded Breadcrumb in `beforeBreadcrumb`"] andLevel:kSentryLogLevelDebug];
        return;
    }
    [self.scope addBreadcrumb:crumb];
}

- (SentryClient *_Nullable)getClient {
    return self.client;
}

- (SentryScope *)getScope {
    if (self.scope == nil) {
        self.scope = [[SentryScope alloc] init];
    }
    return self.scope;
}

- (void)bindClient:(SentryClient * _Nullable)client {
    self.client = client;
}

- (void)configureScope:(void(^)(SentryScope *scope))callback {
    if (nil != self.client && nil != self.scope) {
        callback(self.scope);
    }
}

/**
 * Checks if a specific Integration (`integrationClass`) has been installed.
 * @return BOOL If instance of `integrationClass` exists within `SentryHub.installedIntegrations`.
 */
- (BOOL)isIntegrationInstalled:(Class)integrationClass {
    for (id<SentryIntegrationProtocol> item in SentrySDK.currentHub.installedIntegrations) {
        if ([item isKindOfClass:integrationClass]) {
            return YES;
        }
    }
    return NO;
}

- (id _Nullable)getIntegration:(NSString *)integrationName {
    NSArray *integrations = [self getClient].options.integrations;
    if (![integrations containsObject:integrationName]) {
        return nil;
    }
    return [integrations objectAtIndex:[integrations indexOfObject:integrationName]];
}

@end
