//
//  SentryBreadcrumbs.m
//  Sentry
//
//  Created by Daniel Griesser on 22/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryBreadcrumbs.h>
#import <Sentry/SentryBreadcrumb.h>
#import <Sentry/SentryLog.h>
#import <Sentry/SentryFileManager.h>

#else
#import "SentryBreadcrumbs.h"
#import "SentryBreadcrumb.h"
#import "SentryLog.h"
#import "SentryFileManager.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryBreadcrumbs ()

@property(nonatomic, strong) SentryFileManager *fileManager;
@property(nonatomic, strong) NSMutableArray<SentryBreadcrumb *> *breadcrumbs;
@end

@implementation SentryBreadcrumbs

- (instancetype)init {
    if (self = [super init]) {
        self.maxBreadcrumbs = 50;
        self.breadcrumbs = [NSMutableArray new];
    }
    return self;
}

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb {
    [SentryLog logWithMessage:[NSString stringWithFormat:@"Add breadcrumb: %@", crumb] andLevel:kSentryLogLevelDebug];
    [self.breadcrumbs addObject:crumb];
    if ([self.breadcrumbs count] > self.maxBreadcrumbs) {
        [self.breadcrumbs removeObjectAtIndex:0];
    }
}

- (NSUInteger)count {
    return [self.breadcrumbs count];
}

- (void)clear {
    [self.breadcrumbs removeAllObjects];
}

- (NSDictionary<NSString *, id> *)serialize {
    NSMutableDictionary *serializedData = [NSMutableDictionary new];
    
    NSMutableArray *crumbs = [NSMutableArray new];
    for (SentryBreadcrumb *crumb in self.breadcrumbs) {
        id serializedCrumb = [NSJSONSerialization JSONObjectWithData:[crumb serialize][@"data"] options:0 error:nil];
        if (serializedCrumb != nil) {
            [crumbs addObject:serializedCrumb];
        }
    }
    if (crumbs.count > 0) {
        [serializedData setValue:crumbs forKey:@"breadcrumbs"];
    }
    
    return serializedData;
}

@end

NS_ASSUME_NONNULL_END

