//
//  SentryTraceProfilerHelper.h
//  Sentry
//
//  Created by itaybrenner on 8/28/25.
//  Copyright © 2025 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Helper class to expose SentryTimerFactory to ObjectiveC++ files since we
// can't import modules from there (no @import Sentry)
@interface SentryTraceProfilerHelper : NSObject
+ (NSTimer *)timerWithTimeInterval:(NSTimeInterval)interval
                           repeats:(BOOL)repeats
                             block:(void (^)(NSTimer *timer))block;
@end

NS_ASSUME_NONNULL_END
