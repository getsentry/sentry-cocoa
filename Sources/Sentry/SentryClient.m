//
//  SentryClient.m
//  Sentry
//
//  Created by Daniel Griesser on 02/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryClient.h>
#import <Sentry/SentryLog.h>
#import <Sentry/SentryDsn.h>
#import <Sentry/SentryError.h>
#import <Sentry/SentryUser.h>
#import <Sentry/SentryQueueableRequestManager.h>
#import <Sentry/SentryEvent.h>
#import <Sentry/SentryNSURLRequest.h>
#import <Sentry/SentryInstallation.h>
#import <Sentry/SentryFileManager.h>
#import <Sentry/SentryBreadcrumbTracker.h>
#import <Sentry/SentryCrash.h>
#import <Sentry/SentryOptions.h>
#import <Sentry/SentryScope.h>
#import <Sentry/SentryTransport.h>
#import <Sentry/SentrySDK.h>
#import <Sentry/SentryIntegrationProtocol.h>
#import <Sentry/SentryGlobalEventProcessor.h>

#else
#import "SentryClient.h"
#import "SentryLog.h"
#import "SentryDsn.h"
#import "SentryError.h"
#import "SentryUser.h"
#import "SentryQueueableRequestManager.h"
#import "SentryEvent.h"
#import "SentryNSURLRequest.h"
#import "SentryInstallation.h"
#import "SentryFileManager.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryCrash.h"
#import "SentryOptions.h"
#import "SentryScope.h"
#import "SentryTransport.h"
#import "SentrySDK.h"
#import "SentryIntegrationProtocol.h"
#import "SentryGlobalEventProcessor.h"
#endif

#if SENTRY_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryClient ()

@property(nonatomic, strong) SentryTransport* transport;

@end

@implementation SentryClient

@synthesize options = _options;
@synthesize transport = _transport;

#pragma mark Initializer

- (_Nullable instancetype)initWithOptions:(SentryOptions *)options {
    if (self = [super init]) {
        self.options = options;
        [self.transport sendAllStoredEvents];
    }
    return self;
}

- (SentryTransport *)transport {
    if (_transport == nil) {
        _transport = [[SentryTransport alloc] initWithOptions:self.options];
    }
    return _transport;
}

- (void)captureMessage:(NSString *)message withScopes:(NSArray<SentryScope *> *_Nullable)scopes {
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityInfo];
    // TODO: Attach stacktrace?
    event.message = message;
    [self captureEvent:event withScopes:scopes];
}

- (void)captureException:(NSException *)exception withScopes:(NSArray<SentryScope *> *_Nullable)scopes {
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityError];
    // TODO: Capture Stacktrace
    event.message = exception.reason;
    [self captureEvent:event withScopes:scopes];
}

- (void)captureError:(NSError *)error withScopes:(NSArray<SentryScope *> *_Nullable)scopes {
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityError];
    // TODO: Capture Stacktrace
    event.message = error.localizedDescription;
    [self captureEvent:event withScopes:scopes];
}

- (void)captureEvent:(SentryEvent *)event withScopes:(NSArray<SentryScope *>*_Nullable)scopes {
    SentryEvent *preparedEvent = [self prepareEvent:event withScopes:scopes];
    if (nil != preparedEvent) {
        if (nil != self.options.beforeSend) {
            event = self.options.beforeSend(event);
        }
        if (nil != event) {
            [self.transport sendEvent:preparedEvent withCompletionHandler:nil];
        }
    }
}

/**
 * returns BOOL chance of YES is defined by sampleRate.
 * if sample rate isn't within 0.0 - 1.0 it returns YES (like if sampleRate is 1.0)
 */
- (BOOL)checkSampleRate:(NSNumber *)sampleRate {
    if (nil == sampleRate || [sampleRate floatValue] < 0 || [sampleRate floatValue] > 1) {
        return YES;
    }
    return ([sampleRate floatValue] >= ((double)arc4random() / 0x100000000));
}

#pragma mark prepareEvent

- (SentryEvent *_Nullable)prepareEvent:(SentryEvent *)event
                            withScopes:(NSArray<SentryScope *>*_Nullable)scopes {
    NSParameterAssert(event);
    
    if (NO == [self.options.enabled boolValue]) {
        [SentryLog logWithMessage:@"SDK is disabled, will not do anything" andLevel:kSentryLogLevelDebug];
        return nil;
    }
    
    if (NO == [self checkSampleRate:self.options.sampleRate]) {
        [SentryLog logWithMessage:@"Event got sampled, will not send the event" andLevel:kSentryLogLevelDebug];
        return nil;
    }    

    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    if (nil != infoDict && nil == event.releaseName) {
        event.releaseName = [NSString stringWithFormat:@"%@@%@+%@", infoDict[@"CFBundleIdentifier"], infoDict[@"CFBundleShortVersionString"],
            infoDict[@"CFBundleVersion"]];
    }
    if (nil != infoDict && nil == event.dist) {
        event.dist = infoDict[@"CFBundleVersion"];
    }

    // Options win over default, and scope wins over options
    // So the order matters
    NSString *releaseName = self.options.releaseName;
    if (nil != releaseName) {
        event.releaseName = releaseName;
    }

    NSString *dist = self.options.dist;
    if (nil != dist) {
        event.dist = dist;
    }
    
    NSString *environment = self.options.environment;
    if (nil != environment && nil == event.environment) {
        event.environment = environment;
    }
    
    if (nil != scopes) {
        for (SentryScope *scope in scopes) {
            event = [scope applyToEvent:event maxBreadcrumb:self.options.maxBreadcrumbs];
        }
    }
    
    return [self callEventProcessors:event];
}

- (SentryEvent *)callEventProcessors:(SentryEvent *)event {
    SentryEvent *newEvent = event;

    for (SentryEventProcessor processor in SentryGlobalEventProcessor.shared.processors) {
        newEvent = processor(newEvent);
        if (nil == newEvent) {
            [SentryLog logWithMessage:@"SentryScope callEventProcessors: an event processor decided to remove this event." andLevel:kSentryLogLevelDebug];
            break;
        }
    }
    return newEvent;
}


@end

NS_ASSUME_NONNULL_END
