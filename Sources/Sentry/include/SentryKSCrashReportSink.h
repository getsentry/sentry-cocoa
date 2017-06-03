//
//  SentryKSCrashReportSink.h
//  Sentry
//
//  Created by Daniel Griesser on 10/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#if WITH_KSCRASH
#import <KSCrash/KSCrash.h>
@interface SentryKSCrashReportSink : NSObject <KSCrashReportFilter>
#else

@interface SentryKSCrashReportSink : NSObject
#endif

@end
