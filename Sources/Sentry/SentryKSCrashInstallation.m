//
//  SentryKSCrashInstallation.m
//  Sentry
//
//  Created by Daniel Griesser on 10/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<KSCrash/KSCrash.h>)
#import <KSCrash/KSCrash.h>
#import <KSCrash/KSCrashInstallation+Private.h>
#endif

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryKSCrashInstallation.h>
#import <Sentry/SentryKSCrashReportSink.h>
#import <Sentry/SentryLog.h>

#else
#import "SentryKSCrashInstallation.h"
#import "SentryKSCrashReportSink.h"
#import "SentryLog.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation SentryKSCrashInstallation

#if __has_include(<KSCrash/KSCrash.h>)

- (id)init {
    return [super initWithRequiredProperties:@[]];
}

- (id<KSCrashReportFilter>)sink {
    return [[SentryKSCrashReportSink alloc] init];
}

- (void)sendAllReports {
    [super sendAllReportsWithCompletion:^(NSArray *filteredReports, BOOL completed, NSError *error) {
        if (nil != error) {
            [SentryLog logWithMessage:error.localizedDescription andLevel:kSentryLogLevelError];
        }
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Sent %lu crash report(s)", (unsigned long)filteredReports.count] andLevel:kSentryLogLevelDebug];
    }];
}

#else
- (void)sendAllReports {
    [SentryLog logWithMessage:@"This function does nothing if there is no KSCrash" andLevel:kSentryLogLevelError];
}
#endif

@end

NS_ASSUME_NONNULL_END
