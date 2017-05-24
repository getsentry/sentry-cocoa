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

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (_Nullable instancetype)initWithError:(NSError **)error;
- (void)storeEvent:(SentryEvent *)event didFailWithError:(NSError **)error;
- (void)storeBreadcrumb:(SentryBreadcrumb *)crumb didFailWithError:(NSError **)error;
+ (BOOL)createDirectoryAtPath:(NSString *)path withError:(NSError **)error;
- (void)deleteAllStoredEvents;
- (void)deleteAllStoredBreadcrumbs;
- (void)deleteAllFolders;
- (NSArray<NSDictionary<NSString *, id>*> *)getAllStoredEvents;
- (NSArray<NSDictionary<NSString *, id>*> *)getAllStoredBreadcrumbs;
- (BOOL)removeFileAtPath:(NSString *)path;
- (NSArray<NSString *> *)allFilesInFolder:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
