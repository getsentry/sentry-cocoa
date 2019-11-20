//
//  SentryScope.h
//  Sentry
//
//  Created by Klemens Mantzos on 15.11.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryDefines.h>
#import <Sentry/SentryFileManager.h>
#import <Sentry/SentryOptions.h>

#else
#import "SentryDefines.h"
#import "SentryFileManager.h"
#import "SentryOptions.h"
#endif

@class SentryBreadcrumbStore, SentryUser;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Scope)
@interface SentryScope : NSObject
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptions *_Nonnull)options;

/**
 * Set global user -> thus will be sent with every event
 */
@property(nonatomic, strong) SentryUser *_Nullable user;

/**
 * Set global tags -> these will be sent with every event
 */
@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *_Nullable tags;

/**
 * Set global extra -> these will be sent with every event
 */
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable extra;

/**
 * Contains the breadcrumbs which will be sent with the event
 */
@property(nonatomic, strong) SentryBreadcrumbStore *breadcrumbs;

@end

NS_ASSUME_NONNULL_END
