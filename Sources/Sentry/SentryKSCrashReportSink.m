//
//  SentryKSCrashReportSink.m
//  Sentry
//
//  Created by Daniel Griesser on 10/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<KSCrash/KSCrash.h>)
#import <KSCrash/KSCrash.h>
#endif

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryKSCrashReportSink.h>
#import <Sentry/SentryKSCrashReportConverter.h>
#import <Sentry/SentryClient.h>

#else
#import "SentryKSCrashReportSink.h"
#import "SentryKSCrashReportConverter.h"
#import "SentryClient.h"
#endif

@implementation SentryKSCrashReportSink

#if __has_include(<KSCrash/KSCrash.h>)
- (void)filterReports:(NSArray *)reports
          onCompletion:(KSCrashReportFilterCompletion)onCompletion {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        for (NSDictionary *report in reports) {
            SentryKSCrashReportConverter *reportConverter = [[SentryKSCrashReportConverter alloc] initWithReport:report];
            if (nil != SentryClient.sharedClient) {
                [SentryClient.sharedClient sendEvent:[reportConverter converReportToEvent] withCompletionHandler:NULL];
            }
        }
        // TODO we need todo more here
        if (onCompletion) {
            onCompletion(reports, YES, nil);
        }
    });
    
}
#endif

@end
