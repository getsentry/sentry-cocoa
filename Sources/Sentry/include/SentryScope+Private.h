//
//  SentryScope+Private.h
//  Sentry
//
//  Created by Daniel Griesser on 25.02.20.
//  Copyright © 2020 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryScope.h>
#else
#import "SentryScope.h"
#endif

NS_ASSUME_NONNULL_BEGIN

typedef void(^SentryScopeListener)(SentryScope *scope);

@interface SentryScope (Private)

@property (nonatomic, retain) NSMutableArray<SentryScopeListener> *listeners;

- (void)addScopeListener:(SentryScopeListener)listener;
- (void)notifyListeners;

@end

NS_ASSUME_NONNULL_END
