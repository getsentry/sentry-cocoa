// Adapted from
// https://github.com/bugsnag/bugsnag-cocoa/blob/2f373f21b965f1b13d7070662e2d35f46c17d975/Bugsnag/Delivery/BSGConnectivity.m
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

static NSHashTable<id<SentryReachabilityObserver>> *sentry_reachability_observers;
static SCNetworkReachabilityFlags sentry_current_reachability_state
    = kSCNetworkReachabilityFlagsUninitialized;
static dispatch_queue_t sentry_reachability_queue;

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
        SENTRY_LOG_DEBUG(@"No change in reachability state. SentryConnectivityShouldReportChange "
                         @"will return NO for flags %u, sentry_current_reachability_state %u",
            flags, sentry_current_reachability_state);
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
    SENTRY_LOG_DEBUG(
        @"SentryConnectivityCallback called with target: %@; flags: %u", target, flags);

    @synchronized(sentry_reachability_observers) {
        SENTRY_LOG_DEBUG(
            @"Entered synchronized region of SentryConnectivityCallback with target: %@; flags: %u",
            target, flags);

        if (sentry_reachability_observers.count == 0) {
            SENTRY_LOG_DEBUG(@"No reachability observers registered. Nothing to do.");
            return;
        }

        if (!SentryConnectivityShouldReportChange(flags)) {
            SENTRY_LOG_DEBUG(@"SentryConnectivityShouldReportChange returned NO for flags %u, will "
                             @"not report change to observers.",
                flags);
            return;
        }

        BOOL connected = (flags & kSCNetworkReachabilityFlagsReachable) != 0;

        SENTRY_LOG_DEBUG(@"Notifying observers...");
        for (id<SentryReachabilityObserver> observer in sentry_reachability_observers) {
            SENTRY_LOG_DEBUG(@"Notifying %@", observer);
            [observer connectivityChanged:connected
                          typeDescription:SentryConnectivityFlagRepresentation(flags)];
        }
        SENTRY_LOG_DEBUG(@"Finished notifying observers.");
    }
}

@implementation SentryReachability

+ (void)initialize
{
    if (self == [SentryReachability class]) {
        sentry_reachability_observers = [NSHashTable weakObjectsHashTable];
    }
}

- (instancetype)init
{
    if (self = [super init]) {
        self.setReachabilityCallback = YES;
    }

    return self;
}

- (void)addObserver:(id<SentryReachabilityObserver>)observer;
{
    SENTRY_LOG_DEBUG(@"Adding observer: %@", observer);
    @synchronized(sentry_reachability_observers) {
        SENTRY_LOG_DEBUG(@"Synchronized to add observer: %@", observer);
        if ([sentry_reachability_observers containsObject:observer]) {
            SENTRY_LOG_DEBUG(@"Observer already added. Doing nothing.");
            return;
        }

        [sentry_reachability_observers addObject:observer];

        if (sentry_reachability_observers.count > 1) {
            return;
        }

        if (!self.setReachabilityCallback) {
            SENTRY_LOG_DEBUG(@"Skipping setting reachability callback.");
            return;
        }

        sentry_reachability_queue
            = dispatch_queue_create("io.sentry.cocoa.connectivity", DISPATCH_QUEUE_SERIAL);
        _sentry_reachability_ref = SCNetworkReachabilityCreateWithName(NULL, "sentry.io");
        if (!_sentry_reachability_ref) { // Can be null if a bad hostname was specified
            return;
        }

        SENTRY_LOG_DEBUG(@"registering callback for reachability ref %@", _sentry_reachability_ref);
        SCNetworkReachabilitySetCallback(
            _sentry_reachability_ref, SentryConnectivityCallback, NULL);
        SCNetworkReachabilitySetDispatchQueue(_sentry_reachability_ref, sentry_reachability_queue);
    }
}

- (void)removeObserver:(id<SentryReachabilityObserver>)observer
{
    SENTRY_LOG_DEBUG(@"Removing observer: %@", observer);
    @synchronized(sentry_reachability_observers) {
        SENTRY_LOG_DEBUG(@"Synchronized to remove observer: %@", observer);
        [sentry_reachability_observers removeObject:observer];

        if (sentry_reachability_observers.count == 0) {
            [self unsetReachabilityCallback];
        }
    }
}

- (void)removeAllObservers
{
    SENTRY_LOG_DEBUG(@"Removing all observers.");
    @synchronized(sentry_reachability_observers) {
        SENTRY_LOG_DEBUG(@"Synchronized to remove all observers.");
        [sentry_reachability_observers removeAllObjects];
        [self unsetReachabilityCallback];
    }
}

- (void)unsetReachabilityCallback
{
    sentry_current_reachability_state = kSCNetworkReachabilityFlagsUninitialized;

    if (_sentry_reachability_ref != nil) {
        SENTRY_LOG_DEBUG(@"removing callback for reachability ref %@", _sentry_reachability_ref);
        SCNetworkReachabilitySetCallback(_sentry_reachability_ref, NULL, NULL);
        SCNetworkReachabilitySetDispatchQueue(_sentry_reachability_ref, NULL);
        _sentry_reachability_ref = nil;
    }

    SENTRY_LOG_DEBUG(@"Cleaning up reachability queue.");
    sentry_reachability_queue = nil;
}

@end

#endif // !TARGET_OS_WATCH
