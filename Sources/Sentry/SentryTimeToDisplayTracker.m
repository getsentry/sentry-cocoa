#import "SentryTimeToDisplayTracker.h"
#import "SentryCurrentDate.h"
#import "SentryFramesTracker.h"
#import "SentrySpan.h"
#import "SentrySpanContext.h"
#import "SentrySpanId.h"
#import "SentrySpanOperations.h"
#import "SentrySwift.h"
#import "SentryTracer.h"

#if SENTRY_HAS_UIKIT

@interface
SentryTimeToDisplayTracker () <SentryFramesTrackerListener>

@property (nonatomic, weak) SentrySpan *initialDisplaySpan;
@property (nonatomic, weak) SentrySpan *fullDisplaySpan;

@end

@implementation SentryTimeToDisplayTracker {
    BOOL _waitForFullDisplay;
    BOOL _isReadyToDisplay;
    BOOL _fullyDisplayedReported;
    SentryFramesTracker *_frameTracker;
    NSString *_controllerName;
}

- (instancetype)initForController:(UIViewController *)controller
                    framesTracker:(SentryFramesTracker *)framestracker
               waitForFullDisplay:(BOOL)waitForFullDisplay
{
    if (self = [super init]) {
        _controllerName = [SwiftDescriptor getObjectClassName:controller];
        _waitForFullDisplay = waitForFullDisplay;
        _frameTracker = framestracker;

        _isReadyToDisplay = NO;
        _fullyDisplayedReported = NO;
    }
    return self;
}

- (void)startForTracer:(SentryTracer *)tracer
{
    self.initialDisplaySpan = [tracer
        startChildWithOperation:SentrySpanOperationUILoadInitialDisplay
                    description:[NSString stringWithFormat:@"%@ initial display", _controllerName]];

    if (self.waitForFullDisplay) {
        self.fullDisplaySpan =
            [tracer startChildWithOperation:SentrySpanOperationUILoadFullDisplay
                                description:[NSString stringWithFormat:@"%@ full display",
                                                      _controllerName]];

        // By concept TTID and TTFD spans should have the same beginning,
        // which also should be the same of the transaction starting.
        self.fullDisplaySpan.startTimestamp = tracer.startTimestamp;
    }

    self.initialDisplaySpan.startTimestamp = tracer.startTimestamp;

    [_frameTracker addListener:self];
    [tracer setFinishCallback:^(
        SentryTracer *_tracer) { [self trimTTFDIdNecessaryForTracer:_tracer]; }];
}

- (void)reportReadyToDisplay
{
    _isReadyToDisplay = YES;
}

- (void)reportFullyDisplayed
{
    _fullyDisplayedReported = YES;
    if (self.waitForFullDisplay && _isReadyToDisplay) {
        [self.fullDisplaySpan finish];
    }
}

- (void)framesTrackerHasNewFrame
{
    // The purpose of TTID and TTFD is to measure how long
    // takes to the content of the screen to change.
    // Thats why we need to wait for the next frame to be drawn.
    if (_waitForFullDisplay && _fullyDisplayedReported && self.fullDisplaySpan.isFinished == NO) {
        [self.fullDisplaySpan finish];
    }
    if (_isReadyToDisplay && self.initialDisplaySpan.isFinished == NO) {
        [self.initialDisplaySpan finish];
        [_frameTracker removeListener:self];
    }
}

- (void)trimTTFDIdNecessaryForTracer:(SentryTracer *)tracer
{
    if (self.fullDisplaySpan.status != kSentrySpanStatusDeadlineExceeded) {
        return;
    }

    self.fullDisplaySpan.timestamp = self.initialDisplaySpan.timestamp;
    self.fullDisplaySpan.spanDescription =
        [NSString stringWithFormat:@"%@ - Deadline Exceeded", self.fullDisplaySpan.spanDescription];
}

@end
#endif
