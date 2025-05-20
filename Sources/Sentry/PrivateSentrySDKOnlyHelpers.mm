//
//  PrivateSentrySDKOnlyHelpers.mm
//  Sentry
//
//  Created by Noah Martin on 5/20/25.
//  Copyright © 2025 Sentry. All rights reserved.
//

#import "PrivateSentrySDKOnlyHelpers.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryInternalDefines.h"
#    import "SentryProfilerSerialization.h"
#    import "SentrySDK+Private.h"
#    import "SentryThreadHandle.hpp"

@implementation PrivateSentrySDKOnlyHelpers

+ (nullable NSMutableDictionary<NSString *, id> *)collectProfileBetween:(uint64_t)startSystemTime
                                                                    and:(uint64_t)endSystemTime
                                                               forTrace:(NSString *)traceId;
{
    NSMutableDictionary<NSString *, id> *payload = sentry_collectProfileDataHybridSDK(
        startSystemTime, endSystemTime, traceId, [SentrySDK currentHub]);

    if (payload != nil) {
        payload[@"platform"] = SentryPlatformName;
        payload[@"transaction"] = @{
            @"active_thread_id" :
                [NSNumber numberWithLongLong:sentry::profiling::ThreadHandle::current()->tid()]
        };
    }

    return payload;
}

@end

#endif
