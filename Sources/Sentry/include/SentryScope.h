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
#import <Sentry/SentryBreadcrumb.h>
#import <Sentry/SentryOptions.h>
#import <Sentry/SentrySerializable.h>

#else
#import "SentryDefines.h"
#import "SentryBreadcrumb.h"
#import "SentryOptions.h"
#import "SentrySerializable.h"
#endif

@class SentryUser;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Scope)
@interface SentryScope : NSObject <SentrySerializable>

- (instancetype)init;
- (instancetype)initWithScope:(SentryScope *)scope;

/**
 * Set global user -> thus will be sent with every event
 */
- (void)setUser:(SentryUser * _Nullable)user;

/**
 * Set global tags -> these will be sent with every event
 */
- (void)setTags:(NSDictionary<NSString *, NSString *> *_Nullable)tags;

/**
 * Set global extra -> these will be sent with every event
 */
- (void)setTagValue:(id)value forKey:(NSString *)key NS_SWIFT_NAME(setTag(value:key:));

/**
 * Set global extra -> these will be sent with every event
 */
- (void)setExtras:(NSDictionary<NSString *, id> *_Nullable)extras;

/**
 * Set global extra -> these will be sent with every event
 */
- (void)setExtraValue:(id)value forKey:(NSString *)key NS_SWIFT_NAME(setExtra(value:key:));

/**
 * Set release in the scope
 */
- (void)setRelease:(NSString *_Nullable)releaseName;

/**
 * Set dist in the scope
 */
- (void)setDist:(NSString *_Nullable)dist;

/**
* Set environment in the scope
*/
- (void)setEnvironment:(NSString *_Nullable)environment;

/**
* Sets the fingerprint in the scope
*/
- (void)setFingerprint:(NSArray<NSString *> *_Nullable)fingerprint;

/**
* Sets the level in the scope
*/
- (void)setLevel:(enum SentryLevel)level;

/**
 * Add a breadcrumb to the scope
 */
- (void)addBreadcrumb:(SentryBreadcrumb *)crumb;

/**
 * Clears all breadcrumbs in the scope
 */
- (void)clearBreadcrumbs;

/**
 * Serializes the Scope to JSON
 */
- (NSDictionary<NSString *, id> *)serialize;

/**
 * Adds the Scope to the event
 */
- (SentryEvent * __nullable)applyToEvent:(SentryEvent *)event maxBreadcrumb:(NSUInteger)maxBreadcrumbs;

/**
 * Cets context values which will overwrite SentryEvent.context when event is
 * "enrichted" with scope before sending event.
 */
- (void)setContextValue:(NSDictionary<NSString *, id>*)value forKey:(NSString *)key NS_SWIFT_NAME(setContext(value:key:));

/**
 * Clears the current Scope
 */
- (void)clear;

@end

NS_ASSUME_NONNULL_END
