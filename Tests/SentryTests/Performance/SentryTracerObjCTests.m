#import "SentryHub.h"
#import "SentrySpan.h"
#import "SentryTracer.h"
#import "SentryTransactionContext.h"
#import <XCTest/XCTest.h>

@interface SentryTracerObjCTests : XCTestCase

@end

@implementation SentryTracerObjCTests

/**
 * This test makes sure that the span has a weak reference to the tracer and doesn't call the
 * tracer#spanFinished method.
 */
- (void)testSpanFinishesAfterTracerReleased_NoCrash_TracerIsNil
{
    SentrySpan *child;
    // To make sure the tracer is deallocated.
    @autoreleasepool {
        SentryHub *hub = [[SentryHub alloc] initWithClient:nil andScope:nil];
        SentryTransactionContext *context =
            [[SentryTransactionContext alloc] initWithOperation:@""];
        SentryTracer *tracer = [[SentryTracer alloc] initWithTransactionContext:context
                                                                            hub:hub
                                                        profilesSamplerDecision:nil
                                                                waitForChildren:YES];
        [tracer finish];
        child = [tracer startChildWithOperation:@"child"];
    }

    XCTAssertNotNil(child);
    [child finish];
}

@end
