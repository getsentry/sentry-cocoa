//
//  SentryFileManager.m
//  Sentry
//
//  Created by Daniel Griesser on 23/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryFileManager.h>
#import <Sentry/SentryError.h>
#import <Sentry/SentryLog.h>
#import <Sentry/SentryEvent.h>
#import <Sentry/SentryDsn.h>
#import <Sentry/SentrySerialization.h>
#else
#import "SentryFileManager.h"
#import "SentryError.h"
#import "SentryLog.h"
#import "SentryEvent.h"
#import "SentryDsn.h"
#import "SentrySerialization.h"
#endif

NS_ASSUME_NONNULL_BEGIN

NSInteger const defaultMaxEvents = 10;

@interface SentryFileManager ()

@property(nonatomic, copy) NSString *sentryPath;
@property(nonatomic, copy) NSString *eventsPath;
@property(nonatomic, assign) NSUInteger currentFileCounter;

@end

@implementation SentryFileManager

- (_Nullable instancetype)initWithDsn:(SentryDsn *)dsn didFailWithError:(NSError **)error {
    self = [super init];
    if (self) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
        
        self.sentryPath = [cachePath stringByAppendingPathComponent:@"io.sentry"];
        self.sentryPath = [self.sentryPath stringByAppendingPathComponent:[dsn getHash]];
        
        if (![fileManager fileExistsAtPath:self.sentryPath]) {
            [self.class createDirectoryAtPath:self.sentryPath withError:error];
        }

        self.eventsPath = [self.sentryPath stringByAppendingPathComponent:@"events"];
        if (![fileManager fileExistsAtPath:self.eventsPath]) {
            [self.class createDirectoryAtPath:self.eventsPath withError:error];
        }

        self.currentFileCounter = 0;
        self.maxEvents = defaultMaxEvents;
    }
    return self;
}

- (void)deleteAllFolders {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:self.eventsPath error:nil];
    [fileManager removeItemAtPath:self.sentryPath error:nil];
}

- (NSString *)uniqueAcendingJsonName {
    return [NSString stringWithFormat:@"%f-%lu-%@.json",
                                      [[NSDate date] timeIntervalSince1970],
                                      (unsigned long) self.currentFileCounter++,
                                      [NSUUID UUID].UUIDString];
}

- (NSArray<NSDictionary<NSString *, id> *> *)getAllStoredEvents {
    return [self allFilesContentInFolder:self.eventsPath];
}

- (NSArray<NSDictionary<NSString *, id> *> *)allFilesContentInFolder:(NSString *)path {
    @synchronized (self) {
        NSMutableArray *contents = [NSMutableArray new];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        for (NSString *filePath in [self allFilesInFolder:path]) {
            NSString *finalPath = [path stringByAppendingPathComponent:filePath];
            NSData *content = [fileManager contentsAtPath:finalPath];
            if (nil != content) {
                [contents addObject:@{@"path": finalPath, @"data": content}];
            }
        }
        return contents;
    }
}

- (void)deleteAllStoredEvents {
    for (NSString *path in [self allFilesInFolder:self.eventsPath]) {
        [self removeFileAtPath:[self.eventsPath stringByAppendingPathComponent:path]];
    }
}

- (NSArray<NSString *> *)allFilesInFolder:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray <NSString *> *storedFiles = [fileManager contentsOfDirectoryAtPath:path error:&error];
    if (nil != error) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Couldn't load files in folder %@: %@", path, error] andLevel:kSentryLogLevelError];
        return [NSArray new];
    }
    return [storedFiles sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (BOOL)removeFileAtPath:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    @synchronized (self) {
        [fileManager removeItemAtPath:path error:&error];
        if (nil != error) {
            [SentryLog logWithMessage:[NSString stringWithFormat:@"Couldn't delete file %@: %@", path, error] andLevel:kSentryLogLevelError];
            return NO;
        }
    }
    return YES;
}

- (NSString *)storeEvent:(SentryEvent *)event {
    return [self storeEvent:event maxCount:self.maxEvents];
}

- (NSString *)storeEvent:(SentryEvent *)event maxCount:(NSUInteger)maxCount {
    @synchronized (self) {
        NSString *result;
        if (nil != event.json) {
            result = [self storeData:event.json toPath:self.eventsPath];
        } else {
            result = [self storeDictionary:[event serialize] toPath:self.eventsPath];
        }
        [self handleFileManagerLimit:self.eventsPath maxCount:maxCount];
        return result;
    }
}

- (NSString *)storeEnvelope:(SentryEnvelope *)envelope {
    @synchronized (self) {
        NSString *result = [self storeData:[SentrySerialization dataWithEnvelope:envelope options:0 error:nil] toPath:self.eventsPath];
        [self handleFileManagerLimit:self.eventsPath maxCount:self.maxEvents];
        return result;
    }
}

- (NSString *)storeData:(NSData *)data toPath:(NSString *)path {
    @synchronized (self) {
        NSString *finalPath = [path stringByAppendingPathComponent:[self uniqueAcendingJsonName]];
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Writing to file: %@", finalPath] andLevel:kSentryLogLevelDebug];
        [data writeToFile:finalPath options:NSDataWritingAtomic error:nil];
        return finalPath;
    }
}

- (NSString *)storeDictionary:(NSDictionary *)dictionary toPath:(NSString *)path {
    NSData *saveData = [SentrySerialization dataWithJSONObject:dictionary options:0 error:nil];
    return nil != saveData
            ? [self storeData:saveData toPath:path]
            : path; // TODO: Should we return null instead? Whoever is using this return value is being tricked.
}

- (void)handleFileManagerLimit:(NSString *)path maxCount:(NSUInteger)maxCount {
    NSArray<NSString *> *files = [self allFilesInFolder:path];
    NSInteger numbersOfFilesToRemove = ((NSInteger)files.count) - maxCount;
    if (numbersOfFilesToRemove > 0) {
        for (NSUInteger i = 0; i < numbersOfFilesToRemove; i++) {
            [self removeFileAtPath:[path stringByAppendingPathComponent:[files objectAtIndex:i]]];
        }
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Removed %ld file(s) from <%@>", (long)numbersOfFilesToRemove, [path lastPathComponent]]
                         andLevel:kSentryLogLevelDebug];
    }
}

+ (BOOL)createDirectoryAtPath:(NSString *)path withError:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    return [fileManager createDirectoryAtPath:path
                  withIntermediateDirectories:YES
                                   attributes:nil
                                        error:error];
}

@end

NS_ASSUME_NONNULL_END
