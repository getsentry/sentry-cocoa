//
//  SentryHub.m
//  Sentry
//
//  Created by Klemens Mantzos on 11.11.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryHub.h>
#import <Sentry/SentryClient.h>
#import <Sentry/SentryBreadcrumbStore.h>
#else
#import "SentryHub.h"
#import "SentryClient.h"
#import "SentryBreadcrumbStore.h"
#endif

@interface SentryHub()

@property (nonatomic, strong) SentryClient *client;

@end

@implementation SentryHub

+ (SentryHub *)defaultHub {
    static SentryHub *_sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedInstance = [[self alloc] init];
    });
     
    return _sharedInstance;
}

- (void)startWithOptions:(NSDictionary<NSString *,id> *)options {
    NSError *error = nil;
    
    if (self.client == nil) {
        SentryClient *newClient = [[SentryClient alloc] initWithOptions:options didFailWithError:&error];
        
        [self setClient:newClient];
        
        // TODO(fetzig): remove this as soon as SentryHub is fully capable of managing multiple `SentryClient`s
        [SentryClient setSharedClient:newClient];

        if (nil != error) {
            NSLog(@"%@", error);
        }
    }
    
    // TODO(fetzig): do this via "integration"
    [self.client startCrashHandlerWithError:&error];
    
    if (nil != error) {
        NSLog(@"%@", error);
    }
}

- (void)captureEvent:(SentryEvent *)event {
    [self.client sendEvent:event withCompletionHandler:nil];
}

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb {
    [self.client.breadcrumbs addBreadcrumb:crumb];
}

- (SentryClient *)getClient {
    return self.client;
}

- (void)reset {
    _client = nil;
    [SentryClient setSharedClient:nil];
}

@end
