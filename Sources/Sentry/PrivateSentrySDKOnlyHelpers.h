//
//  PrivateSentrySDKOnlyHelpers.h
//  Sentry
//
//  Created by Noah Martin on 5/20/25.
//  Copyright © 2025 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>
#if __has_include(<Sentry/SentryProfilingConditionals.h>)
#    import <Sentry/SentryProfilingConditionals.h>
#else
#    import "SentryProfilingConditionals.h"
#endif

#if SENTRY_TARGET_PROFILING_SUPPORTED

NS_ASSUME_NONNULL_BEGIN

@interface PrivateSentrySDKOnlyHelpers : NSObject

+ (nullable NSMutableDictionary<NSString *, id> *)collectProfileBetween:(uint64_t)startSystemTime
                                                                    and:(uint64_t)endSystemTime
                                                               forTrace:(NSString *)traceId;

@end

NS_ASSUME_NONNULL_END

#endif
