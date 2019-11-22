//
//  SentryScope.m
//  Sentry
//
//  Created by Klemens Mantzos on 15.11.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryScope.h>
#import <Sentry/SentryClient+Internal.h>
#import <Sentry/SentryLog.h>
#import <Sentry/SentryDsn.h>
#import <Sentry/SentryError.h>
#import <Sentry/SentryUser.h>
#import <Sentry/SentryQueueableRequestManager.h>
#import <Sentry/SentryEvent.h>
#import <Sentry/SentryNSURLRequest.h>
#import <Sentry/SentryInstallation.h>
#import <Sentry/SentryBreadcrumbStore.h>
#import <Sentry/SentryFileManager.h>
#import <Sentry/SentryBreadcrumbTracker.h>
#import <Sentry/SentryCrash.h>
#import <Sentry/SentryOptions.h>
#else
#import "SentryScope.h"
#import "SentryClient+Internal.h"
#import "SentryLog.h"
#import "SentryDsn.h"
#import "SentryError.h"
#import "SentryUser.h"
#import "SentryQueueableRequestManager.h"
#import "SentryEvent.h"
#import "SentryNSURLRequest.h"
#import "SentryInstallation.h"
#import "SentryBreadcrumbStore.h"
#import "SentryFileManager.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryCrash.h"
#import "SentryOptions.h"
#endif

#if SENTRY_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryScope ()

@property(nonatomic, strong) SentryFileManager *fileManager;

@end

@implementation SentryScope

@synthesize tags = _tags;
@synthesize extra = _extra;
@synthesize user = _user;


#pragma mark Initializer

//- (instancetype)initWithOptions:(SentryOptions *_Nonnull)options {
//    if (self = [super init]) {
//        _extra = [NSDictionary new];
//        _tags = [NSDictionary new];
//        NSError *error = nil;
//        self.fileManager = [[SentryFileManager alloc] initWithDsn:options.dsn didFailWithError:&error];
//        if (nil != error) {
//            [SentryLog logWithMessage:error.localizedDescription andLevel:kSentryLogLevelError];
//            return nil;
//        }
//        self.breadcrumbs = [[SentryBreadcrumbStore alloc] initWithFileManager:self.fileManager];
//    }
//    return self;
//}

#pragma mark Global properties

- (void)setTags:(NSDictionary<NSString *, NSString *> *_Nullable)tags {
    [[NSUserDefaults standardUserDefaults] setObject:tags forKey:@"sentry.io.tags"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    _tags = tags;
}

- (void)setExtra:(NSDictionary<NSString *, id> *_Nullable)extra {
    [[NSUserDefaults standardUserDefaults] setObject:extra forKey:@"sentry.io.extra"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    _extra = extra;
}

- (void)setUser:(SentryUser *_Nullable)user {
    [[NSUserDefaults standardUserDefaults] setObject:[user serialize] forKey:@"sentry.io.user"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    _user = user;
}


@end

NS_ASSUME_NONNULL_END
