//
//  SentryReachability.m
//
//  Created by Jamie Lynch on 2017-09-04.
//
//  Copyright (c) 2017 Bugsnag, Inc. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "SentryLog.h"
#import "SentryReachability+Private.h"

#if !TARGET_OS_WATCH

static const SCNetworkReachabilityFlags kSCNetworkReachabilityFlagsUninitialized = UINT32_MAX;

static NSMutableDictionary<NSString *, SentryConnectivityChangeBlock>
    *sentry_reachability_change_blocks;
static SCNetworkReachabilityFlags sentry_current_reachability_state
    = kSCNetworkReachabilityFlagsUninitialized;

NSString *const SentryConnectivityCellular = @"cellular";
NSString *const SentryConnectivityWiFi = @"wifi";
NSString *const SentryConnectivityNone = @"none";

/**
 * Check whether the connectivity change should be noted or ignored.
 * @return @c YES if the connectivity change should be reported
 */
BOOL
SentryConnectivityShouldReportChange(SCNetworkReachabilityFlags flags)
{
#    if SENTRY_HAS_UIKIT
    // kSCNetworkReachabilityFlagsIsWWAN does not exist on macOS
    const SCNetworkReachabilityFlags importantFlags
        = kSCNetworkReachabilityFlagsIsWWAN | kSCNetworkReachabilityFlagsReachable;
#    else // !SENTRY_HAS_UIKIT
    const SCNetworkReachabilityFlags importantFlags = kSCNetworkReachabilityFlagsReachable;
#    endif // SENTRY_HAS_UIKIT

    // Check if the reported state is different from the last known state (if any)
    SCNetworkReachabilityFlags newFlags = flags & importantFlags;
    if (newFlags == sentry_current_reachability_state) {
        return NO;
    }

    sentry_current_reachability_state = newFlags;
    return YES;
}

/**
 * Textual representation of a connection type
 */
NSString *
SentryConnectivityFlagRepresentation(SCNetworkReachabilityFlags flags)
{
    BOOL connected = (flags & kSCNetworkReachabilityFlagsReachable) != 0;
#    if SENTRY_HAS_UIKIT
    return connected ? ((flags & kSCNetworkReachabilityFlagsIsWWAN) ? SentryConnectivityCellular
                                                                    : SentryConnectivityWiFi)
                     : SentryConnectivityNone;
#    else // !SENTRY_HAS_UIKIT
    return connected ? SentryConnectivityWiFi : SentryConnectivityNone;
#    endif // SENTRY_HAS_UIKIT
}

/**
 * Callback invoked by @c SCNetworkReachability, which calls an Objective-C block
 * that handles the connection change.
 */
void
SentryConnectivityCallback(
    __unused SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, __unused void *info)
{
    if (sentry_reachability_change_blocks && SentryConnectivityShouldReportChange(flags)) {
        BOOL connected = (flags & kSCNetworkReachabilityFlagsReachable) != 0;

        for (SentryConnectivityChangeBlock block in sentry_reachability_change_blocks.allValues) {
            block(connected, SentryConnectivityFlagRepresentation(flags));
        }
    }
}

@implementation SentryReachability

+ (void)initialize
{
    if (self == [SentryReachability class]) {
        sentry_reachability_change_blocks = [NSMutableDictionary new];
    }
}

- (void)dealloc
{
    for (id<SentryReachabilityObserver> observer in sentry_reachability_change_blocks.allKeys) {
        [self removeObserver:observer];
    }
}

- (void)addObserver:(id<SentryReachabilityObserver>)observer
       withCallback:(SentryConnectivityChangeBlock)block;
{
    sentry_reachability_change_blocks[[observer description]] = block;

    if (sentry_current_reachability_state != kSCNetworkReachabilityFlagsUninitialized) {
        return;
    }

    static dispatch_once_t once_t;
    static dispatch_queue_t reachabilityQueue;
    dispatch_once(&once_t, ^{
        reachabilityQueue
            = dispatch_queue_create("io.sentry.cocoa.connectivity", DISPATCH_QUEUE_SERIAL);
    });

    _sentry_reachability_ref = SCNetworkReachabilityCreateWithName(NULL, "sentry.io");
    if (!_sentry_reachability_ref) { // Can be null if a bad hostname was specified
        return;
    }

    SENTRY_LOG_DEBUG(@"registering callback for reachability ref %@", _sentry_reachability_ref);
    SCNetworkReachabilitySetCallback(_sentry_reachability_ref, SentryConnectivityCallback, NULL);
    SCNetworkReachabilitySetDispatchQueue(_sentry_reachability_ref, reachabilityQueue);
}

- (void)removeObserver:(id<SentryReachabilityObserver>)observer
{
    [sentry_reachability_change_blocks removeObjectForKey:[observer description]];
    if (sentry_reachability_change_blocks.allValues.count > 0) {
        return;
    }

    sentry_current_reachability_state = kSCNetworkReachabilityFlagsUninitialized;

    if (_sentry_reachability_ref == nil) {
        SENTRY_LOG_WARN(@"No reachability ref to unregister.");
        return;
    }

    SENTRY_LOG_DEBUG(@"removing callback for reachability ref %@", _sentry_reachability_ref);
    SCNetworkReachabilitySetCallback(_sentry_reachability_ref, NULL, NULL);
    SCNetworkReachabilitySetDispatchQueue(_sentry_reachability_ref, NULL);
}

@end

#endif // !TARGET_OS_WATCH
