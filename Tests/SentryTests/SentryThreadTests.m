//
//  SentryThreadTests.m
//  SentryTests
//
//  Created by Daniel Griesser on 31.03.20.
//  Copyright © 2020 Sentry. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Sentry/Sentry.h>

@interface SentryThreadTests : XCTestCase

@end

@implementation SentryThreadTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testDebugStacktrace {
    SentryThread *thread = [[SentryThread alloc] initWithCallStack:[NSString stringWithFormat:@"%@", [NSThread callStackSymbols]]];
    XCTAssertEqualObjects([thread serialize], @{});
}


- (void)testStacktraceString {
NSString *callstack = @"    0   Sentry                              0x000000010dcba7d1 -[SentryClient attachThreadWithStacktraceToEvent:] + 152 \n\
1   Sentry                              0x000000010dcbaaf0 -[SentryClient captureException:withScope:] + 113 \n\
2   Sentry                              0x000000010dcde7f9 -[SentryHub captureException:withScope:] + 99 \n\
3   Sentry                              0x000000010dce3d4b +[SentrySDK captureException:withScope:] + 102 \n\
4   Example                             0x000000010da45c90 $s7Example14ViewControllerC18captureNSExceptionyyypFTf4nd_n + 224 \n\
5   Example                             0x000000010da4519b $s7Example14ViewControllerC13addBreadcrumbyyypFToTm + 59 \n\
6   UIKitCore                           0x00007fff48c1a4d5 -[UIApplication sendAction:to:from:forEvent:] + 83 \n\
7   Sentry                              0x000000010dcb9e2e __44-[SentryBreadcrumbTracker swizzleSendAction]_block_invoke_2 + 1036 \n\
8   UIKitCore                           0x00007fff485cbc83 -[UIControl sendAction:to:forEvent:] + 223 \n\
9   UIKitCore                           0x00007fff485cbfcb -[UIControl _sendActionsForEvents:withEvent:] + 396 \n\
10  UIKitCore                           0x00007fff485caf3c -[UIControl touchesEnded:withEvent:] + 497 \n\
11  UIKitCore                           0x00007fff48c55d10 -[UIWindow _sendTouchesForEvent:] + 1359 \n\
12  UIKitCore                           0x00007fff48c57a95 -[UIWindow sendEvent:] + 4501 \n\
13  UIKitCore                           0x00007fff48c31ed9 -[UIApplication sendEvent:] + 356 \n\
14  UIKit                               0x000000010fc693cb -[UIApplicationAccessibility sendEvent:] + 85 \n\
15  UIKitCore                           0x00007fff48cbc336 __dispatchPreprocessedEventFromEventQueue + 7328 \n\
16  UIKitCore                           0x00007fff48cbf502 __handleEventQueueInternal + 6565 \n\
17  UIKitCore                           0x00007fff48cb606b __handleHIDEventFetcherDrain + 88 \n\
18  CoreFoundation                      0x00007fff23da1c71 __CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE0_PERFORM_FUNCTION__ + 17 \n\
19  CoreFoundation                      0x00007fff23da1b9c __CFRunLoopDoSource0 + 76 \n\
20  CoreFoundation                      0x00007fff23da1374 __CFRunLoopDoSources0 + 180 \n\
21  CoreFoundation                      0x00007fff23d9bf6e __CFRunLoopRun + 974 \n\
22  CoreFoundation                      0x00007fff23d9b884 CFRunLoopRunSpecific + 404 \n\
23  GraphicsServices                    0x00007fff38b5ac1a GSEventRunModal + 139 \n\
24  UIKitCore                           0x00007fff48c19220 UIApplicationMain + 1605 \n\
25  Example                             0x000000010da453ca main + 58 \n\
26  libdyld.dylib                       0x00007fff519b910d start + 1 \n\
27  ???                                 0x0000000000000001 0x0 + 1";
    
    // TODO
    SentryThread *thread = [[SentryThread alloc] initWithCallStack:callstack];
//    XCTAssertEqualObjects([thread serialize], @{
//        @"id": @99,
//        @"stacktrace": @{
//                @"frames": @[
//                        @{}
//                ]
//        },
//    });
}
@end
