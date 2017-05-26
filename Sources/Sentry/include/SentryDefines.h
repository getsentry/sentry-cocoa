//
//  SentryDefines.h
//  Sentry
//
//  Created by Daniel Griesser on 02/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#ifdef __cplusplus
#define SENTRY_EXTERN        extern "C" __attribute__((visibility ("default")))
#else
#define SENTRY_EXTERN        extern __attribute__((visibility ("default")))
#endif

#if TARGET_OS_IOS || TARGET_OS_TV
#define SENTRY_HAS_UIDEVICE 1
#else
#define SENTRY_HAS_UIDEVICE 0
#endif

#if SENTRY_HAS_UIDEVICE || TARGET_OS_WATCH
#define SENTRY_HAS_UIKIT 1
#else
#define SENTRY_HAS_UIKIT 0
#endif

@class SentryEvent, SentryNSURLRequest;

typedef void (^SentryRequestFinished)(NSError *_Nullable error);
typedef void (^SentryBeforeSerializeEvent)(SentryEvent *_Nonnull event);
typedef void (^SentryBeforeSendRequest)(SentryNSURLRequest *_Nonnull request);

typedef NS_ENUM(NSInteger, SentrySeverity) {
    kSentrySeverityFatal = 0,
    kSentrySeverityError = 1,
    kSentrySeverityWarning = 2,
    kSentrySeverityInfo = 3,
    kSentrySeverityDebug = 4,
};

static NSString *_Nonnull const SentrySeverityNames[] = {
        @"fatal",
        @"error",
        @"warning",
        @"info",
        @"debug",
};

