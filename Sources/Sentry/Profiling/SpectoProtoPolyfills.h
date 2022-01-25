//
//  SpectoProtoPolyfills.hpp
//  Sentry
//
//  Created by Andrew McKnight on 1/20/22.
//  Copyright © 2022 Sentry. All rights reserved.
//

#pragma once

#include <string>
#import <Foundation/Foundation.h>

@interface SentryBacktrace: NSObject {
@public
    NSInteger priority;
    NSString *threadName;
    NSString *queueName;
    NSMutableArray *addresses;
}
@end

@interface SentryProfilingEntry: NSObject {
@public
    NSInteger tid;
    SentryBacktrace *backtrace;
    uint64_t elapsedRelativeToStartDateNs;
    uint64_t costNs;
}

@end
