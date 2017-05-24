//
//  SentryFileManager.h
//  Sentry
//
//  Created by Daniel Griesser on 23/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryEvent, SentryBreadcrumb;

@interface SentryFileManager : NSObject

- (_Nullable instancetype)initWithError:(NSError **)error;
- (void)storeEvent:(SentryEvent *)event didFailWithError:(NSError **)error;
- (void)storeBreadcrumb:(SentryBreadcrumb *)crumb didFailWithError:(NSError **)error;
+ (BOOL)createDirectoryAtPath:(NSString *)path withError:(NSError **)error;
- (void)deleteAllStoredEvents;
- (void)deleteAllStoredBreadcrumbs;
- (NSArray<NSData *> *)getAllStoredEvents;
- (NSArray<NSData *> *)getAllStoredBreadcrumbs;

@end

NS_ASSUME_NONNULL_END
