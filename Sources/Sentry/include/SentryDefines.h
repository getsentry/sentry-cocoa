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

typedef void (^SentryQueueableRequestManagerHandler)(NSError *_Nullable error);

typedef NS_ENUM(NSInteger, SentrySeverity) {
    kSentrySeverityFatal = 0,
    kSentrySeverityError = 1,
    kSentrySeverityWarning = 2,
    kSentrySeverityInfo = 3,
    kSentrySeverityDebug = 4,
};
