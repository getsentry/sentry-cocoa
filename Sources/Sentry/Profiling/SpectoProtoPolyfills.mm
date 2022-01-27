//
//  SpectoProtoPolyfills.cpp
//  Sentry
//
//  Created by Andrew McKnight on 1/20/22.
//  Copyright © 2022 Sentry. All rights reserved.
//

#include "SpectoProtoPolyfills.h"
#import "SpectoTime.h"

@implementation SentryBacktrace @end

@implementation SentryProfilingEntry

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    backtrace = [[SentryBacktrace alloc] init];
    return self;
}

@end

@implementation SentryProfilingTraceLogger

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    referenceUptimeNs = specto::time::getUptimeNs();
    return self;
}

@end
