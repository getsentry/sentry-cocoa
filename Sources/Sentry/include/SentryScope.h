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
#import <Sentry/SentrySerializable.h>
#import <Sentry/SentryContext.h>

#else
#import "SentryDefines.h"
#import "SentryFileManager.h"
#import "SentryOptions.h"
#import "SentrySerializable.h"
#import "SentryContext.h"
#endif

@class SentryUser;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Scope)
@interface SentryScope : NSObject <SentrySerializable>

- (instancetype)init;

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
 * used to add values in event context.
 */
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable context;

/**
 * Contains the breadcrumbs which will be sent with the event
 */
@property(nonatomic, strong) NSMutableArray<SentryBreadcrumb *> *breadcrumbs;

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb withMaxBreadcrumbs:(NSUInteger)maxBreadcrumbs;
- (void)clearBreadcrumbs;

- (NSDictionary<NSString *, id> *) serializeBreadcrumbs;
- (NSDictionary<NSString *, id> *) serialize;

- (SentryEvent * __nullable)applyToEvent:(SentryEvent *)event;

/**
 * sets context values which will overwrite SentryEvent.context when event is
 * "enrichted" with scope before sending event.
 */
- (void)setContextValue:(id)value forKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
