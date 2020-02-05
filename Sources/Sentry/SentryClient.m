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

- (void)captureEvent:(SentryEvent *)event withScope:(SentryScope *_Nullable)scope {
    SentryEvent *preparedEvent = [self prepareEvent:event withScope:scope];
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
                             withScope:(SentryScope *)scope {
    NSParameterAssert(event);
    
    if (NO == [self.options.enabled boolValue]) {
        [SentryLog logWithMessage:@"SDK is disabled, will not do anything" andLevel:kSentryLogLevelDebug];
        return nil;
    }
    
    if (NO == [self checkSampleRate:self.options.sampleRate]) {
        [SentryLog logWithMessage:@"Event got sampled, will not send the event" andLevel:kSentryLogLevelDebug];
        return nil;
    }    

    
    NSString *environment = self.options.environment;
    if (nil != environment && nil == event.environment) {
        event.environment = environment;
    }
    
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    if (nil != infoDict) {
        event.releaseName = [NSString stringWithFormat:@"%@@%@+%@", infoDict[@"CFBundleIdentifier"], infoDict[@"CFBundleShortVersionString"],
            infoDict[@"CFBundleVersion"]];
        event.dist = infoDict[@"CFBundleVersion"];
    }

    NSString *releaseName = self.options.releaseName;
    if (nil != releaseName) {
        event.releaseName = releaseName;
    }

    NSString *dist = self.options.dist;
    if (nil != dist) {
        event.dist = dist;
    }

    event = [scope applyToEvent:event];

    return event;
}

@end

NS_ASSUME_NONNULL_END
