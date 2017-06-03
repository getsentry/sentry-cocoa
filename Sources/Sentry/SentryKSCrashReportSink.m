//
//  SentryKSCrashReportSink.m
//  Sentry
//
//  Created by Daniel Griesser on 10/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if WITH_KSCRASH
#import <KSCrash/KSCrash.h>
#endif

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryKSCrashReportSink.h>
#import <Sentry/SentryKSCrashReportConverter.h>
#import <Sentry/SentryClient+Internal.h>
#import <Sentry/SentryClient.h>
#import <Sentry/SentryEvent.h>
#import <Sentry/SentryException.h>
#import <Sentry/SentryLog.h>

#else
#import "SentryKSCrashReportSink.h"
#import "SentryKSCrashReportConverter.h"
#import "SentryClient.h"
#import "SentryClient+Internal.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentryLog.h"
#endif

@implementation SentryKSCrashReportSink

#if WITH_KSCRASH
- (void)filterReports:(NSArray *)reports
          onCompletion:(KSCrashReportFilterCompletion)onCompletion {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        NSMutableArray *sentReports = [NSMutableArray new];
        for (NSDictionary *report in reports) {
            SentryKSCrashReportConverter *reportConverter = [[SentryKSCrashReportConverter alloc] initWithReport:report];
            if (nil != SentryClient.sharedClient) {
                SentryEvent *event = [reportConverter convertReportToEvent];
                if (nil != event.exceptions.firstObject && [event.exceptions.firstObject.value isEqualToString:@"SENTRY_SNAPSHOT"]) {
                    [SentryLog logWithMessage:@"Snapshotting stacktrace" andLevel:kSentryLogLevelDebug];
                    SentryClient.sharedClient._snapshotThreads = event.threads;
                } else {
                    [sentReports addObject:report];
                    [SentryClient.sharedClient sendEvent:event withCompletionHandler:NULL];
                }
            }
        }
        if (onCompletion) {
            onCompletion(sentReports, TRUE, nil);
        }
    });
    
}
#endif

@end
