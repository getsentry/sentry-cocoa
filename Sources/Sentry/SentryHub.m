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

- (instancetype)initWithClient:(SentryClient *)aClient {
    self = [super init];
    if (self) {
        [self bindClient:aClient];
    }
    return self;
}

- (void)captureEvent:(SentryEvent *)event {
    [self.client sendEvent:event withCompletionHandler:nil];
}

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb {
    [self.client.breadcrumbs addBreadcrumb:crumb];
}

- (void)addBreadcrumbs:(NSArray<SentryBreadcrumb *> *)crumblist {
    for (SentryBreadcrumb * item in crumblist) {
        [self.client.breadcrumbs addBreadcrumb:item];
    }
}

- (void)addBreadcrumbWithBlock:(SentryBreadcrumb * _Nonnull (^)(void))block {

    SentryBreadcrumb * result = block();
    [self addBreadcrumb:result];
}

- (void)addBreadcrumbsWithBlock:(NSArray<SentryBreadcrumb *> * _Nonnull (^)(void))block {

    NSArray<SentryBreadcrumb *>* result = block();
    [self addBreadcrumbs:result];
}

- (SentryClient * _Nullable)getClient {
    return self.client;
}

- (void)bindClient:(SentryClient *)aClient {
    [self setClient:aClient];

    // TODO(fetzig): remove this as soon as SentryHub is fully capable of managing multiple `SentryClient`s
    [SentryClient setSharedClient:aClient];
}

- (void)unbindClient {
    [self setClient:nil];

    // TODO(fetzig): remove this as soon as SentryHub is fully capable of managing multiple `SentryClient`s
    [SentryClient setSharedClient:nil];
}

- (void)reset {
    _client = nil;

    // TODO(fetzig): remove this as soon as SentryHub is fully capable of managing multiple `SentryClient`s
    [SentryClient setSharedClient:nil];
}

@end
