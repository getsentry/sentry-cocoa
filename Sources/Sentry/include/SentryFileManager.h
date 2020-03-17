//
//  SentryFileManager.h
//  Sentry
//
//  Created by Daniel Griesser on 23/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryDefines.h>
#else
#import "SentryDefines.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@class SentryEvent, SentryDsn, SentryEnvelope;

@interface SentryFileManager : NSObject
SENTRY_NO_INIT

- (_Nullable instancetype)initWithDsn:(SentryDsn *)dsn didFailWithError:(NSError **)error;

- (NSString *)storeEvent:(SentryEvent *)event;
- (NSString *)storeEnvelope:(SentryEnvelope *)envelope;

+ (BOOL)createDirectoryAtPath:(NSString *)path withError:(NSError **)error;

- (void)deleteAllStoredEvents;

- (void)deleteAllFolders;

- (NSArray<NSDictionary<NSString *, id> *> *)getAllStoredEvents;

- (BOOL)removeFileAtPath:(NSString *)path;

- (NSArray<NSString *> *)allFilesInFolder:(NSString *)path;

- (NSString *)storeDictionary:(NSDictionary *)dictionary toPath:(NSString *)path;

@property(nonatomic, assign) NSUInteger maxEvents;

@end

NS_ASSUME_NONNULL_END
