//
//  SentryBreadcrumbStore.h
//  Sentry
//
//  Created by Daniel Griesser on 22/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentrySerializable.h>

#else
#import "SentrySerializable.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@class SentryBreadcrumb;

@interface SentryBreadcrumbStore : NSObject <SentrySerializable>

@property (nonatomic, assign) NSUInteger maxBreadcrumbs;

- (instancetype)init;
- (void)addBreadcrumb:(SentryBreadcrumb *)crumb;
- (void)clear;

@end

NS_ASSUME_NONNULL_END
