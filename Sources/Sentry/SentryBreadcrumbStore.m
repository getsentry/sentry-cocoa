//
//  SentryBreadcrumbStore.m
//  Sentry
//
//  Created by Daniel Griesser on 22/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//


#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryBreadcrumbStore.h>
#import <Sentry/SentryBreadcrumb.h>
#import <Sentry/SentryLog.h>

#else
#import "SentryBreadcrumbStore.h"
#import "SentryBreadcrumb.h"
#import "SentryLog.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryBreadcrumbStore()

@property (nonatomic, strong) NSMutableArray<SentryBreadcrumb *> *breadcrumbs;

@end

@implementation SentryBreadcrumbStore

- (instancetype)init {
    self = [super init];
    if (self) {
        self.maxBreadcrumbs = 50;
        self.breadcrumbs = [NSMutableArray new];
    }
    return self;
}

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb {
    [SentryLog logWithMessage:[NSString stringWithFormat:@"Add breadcrumb: %@", crumb] andLevel:kSentryLogLevelDebug];
    if (self.maxBreadcrumbs >= self.breadcrumbs.count) {
        [SentryLog logWithMessage:@"Dropped first breadcrumb due limit" andLevel:kSentryLogLevelDebug];
        [self.breadcrumbs removeObjectAtIndex:0];
    }
    [self.breadcrumbs addObject:crumb];
}

- (void)clear {
    self.breadcrumbs = [NSMutableArray new];
}

- (NSDictionary<NSString *,id> *)serialized {
    NSMutableDictionary *serializedData = [NSMutableDictionary new];
    
    NSMutableArray *crumbs = [NSMutableArray new];
    for (SentryBreadcrumb *crumb in self.breadcrumbs) {
        [crumbs addObject:crumb.serialized];
    }
    if (crumbs.count > 0) {
        [serializedData setValue:crumbs forKey:@"breadcrumbs"];
    }
    
    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
