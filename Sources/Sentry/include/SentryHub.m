//
//  SentryHub.m
//  Sentry
//
//  Created by Klemens Mantzos on 11.11.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#import "SentryHub.h"


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

- (void)initWithOptions:(NSDictionary<NSString *,id> *)options {
    NSError *error = nil;
    
    if (self.client == nil) {
        SentryClient *newClient = [[SentryClient alloc] initWithOptions:options didFailWithError:&error];
        
        [self setClient:newClient];
        
        // TODO(fetzig): remove this as soon ass SentryHub is fully capable of managing `SentryClient`s
        SentryClient.sharedClient = _client;
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

- (void)captureError:(NSError *)error {
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityError];
    event.message = error.localizedDescription;
    [self.client sendEvent:event withCompletionHandler:nil];
}

- (void)captureException:(NSException *)exception {
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityError];
    event.message = exception.reason;
    [self.client sendEvent:event withCompletionHandler:nil];
    
}

- (void)captureMessage:(NSString *)message {
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityError];
    event.message = message;
    [self.client sendEvent:event withCompletionHandler:nil];
}

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb {
    //Client.shared?.breadcrumbs.add(Breadcrumb(level: .info, category: "test"))

    //[self.client.breadcrumbs addBreadcrumb:]
}

@end
