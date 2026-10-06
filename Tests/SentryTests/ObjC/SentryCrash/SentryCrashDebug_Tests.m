// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashDebug_Tests.m
//
//  Created by Karl Stenerud on 2012-01-29.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
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

#import <XCTest/XCTest.h>

#import "SentryCrashDebug.h"

@interface SentryCrashDebug_Tests : XCTestCase
@end

@implementation SentryCrashDebug_Tests

// Note: There is no test for the sysctl error handling path in sentrycrashdebug_isBeingTraced.
// We attempted to create a test that verifies the error handling path when sysctl fails,
// but we were unable to find a reliable way to force sysctl to fail in a test environment.
//
// Approaches Tried:
// - Invalid mib array: The function uses a hardcoded mib array with valid parameters
//   ({ CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() }), so we cannot pass invalid parameters.
// - DYLD_INTERPOSE: Attempted to use function interposition to mock sysctl and force it to return
//   an error. This approach doesn't work because DYLD_INTERPOSE only works for dynamically linked
//   symbols, and sysctl calls may be statically linked or resolved before interposition.
// - System resource limits: Attempted to use setrlimit or other restrictions, but these don't
//   reliably cause sysctl to fail for this specific call.
//
// The error handling code path exists in SentryCrashDebug.c and correctly uses
// SENTRY_STRERROR_R(errno) when sysctl fails. The code change itself is correct and
// verified through code review.

@end
