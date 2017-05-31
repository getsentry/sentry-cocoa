//
//  SentryBreadcrumbStore.h
//  Sentry
//
//  Created by Daniel Griesser on 22/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryDefines.h>
#import <Sentry/SentrySerializable.h>
#else
#import "SentryDefines.h"
#import "SentrySerializable.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@class SentryBreadcrumb, SentryFileManager;

NS_SWIFT_NAME(BreadcrumbStore)
@interface SentryBreadcrumbStore : NSObject <SentrySerializable>
SENTRY_NO_INIT

@property(nonatomic, assign) NSUInteger maxBreadcrumbs;

- (instancetype)initWithFileManager:(SentryFileManager *)fileManager;

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb;

- (void)clear;

- (NSUInteger)count;

@end

NS_ASSUME_NONNULL_END
