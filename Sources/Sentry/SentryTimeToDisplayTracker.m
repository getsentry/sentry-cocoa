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

@property (nonatomic, strong) SentrySpan *initialDisplaySpan;
@property (nonatomic, strong) SentrySpan *fullDisplaySpan;

@end

@implementation SentryTimeToDisplayTracker {
    BOOL _waitForFullDisplay;
    BOOL _isReadyToDisplay;
    BOOL _fullyDisplayedReported;
    SentryFramesTracker *_frameTracker;
    NSString *_controllerName;
}

- (instancetype)initForController:(UIViewController *)controller
               waitForFullDisplay:(BOOL)waitForFullDisplay
{
    return [self initForController:controller
                      frameTracker:SentryFramesTracker.sharedInstance
                waitForFullDisplay:waitForFullDisplay];
}

- (instancetype)initForController:(UIViewController *)controller
                     frameTracker:(SentryFramesTracker *)frametracker
               waitForFullDisplay:(BOOL)waitForFullDisplay
{
    if (self = [super init]) {
        _controllerName = [SwiftDescriptor getObjectClassName:controller];
        _waitForFullDisplay = waitForFullDisplay;
        _frameTracker = frametracker;

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

        // By concept this two spans should have the same beginning,
        // which also should be the same of the transaction starting.
        self.fullDisplaySpan.startTimestamp = tracer.startTimestamp;
        self.initialDisplaySpan.startTimestamp = tracer.startTimestamp;
    }

    [_frameTracker addListener:self];
    [tracer setFinishCallback:^(
        SentryTracer *_tracer) { [self trimTTFDIdNecessaryForTracer:_tracer]; }];
}

- (void)reportInitialDisplay
{
    if (self.initialDisplaySpan.timestamp != nil) {
        return;
    }

    self.initialDisplaySpan.timestamp = [SentryCurrentDate date];

    if (self.fullDisplaySpan.timestamp != nil &&
        [self.fullDisplaySpan.timestamp compare:self.initialDisplaySpan.timestamp]
            == NSOrderedAscending) {
        self.fullDisplaySpan.timestamp = self.initialDisplaySpan.timestamp;
    }
    [self.initialDisplaySpan finish];
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
    if (_fullyDisplayedReported && self.fullDisplaySpan.isFinished == NO) {
        [self.fullDisplaySpan finish];
    }
    if (_isReadyToDisplay && self.initialDisplaySpan.isFinished == NO) {
        [self reportInitialDisplay];
        [SentryFramesTracker.sharedInstance removeListener:self];
    }
}

- (void)trimTTFDIdNecessaryForTracer:(SentryTracer *)tracer
{
    if (self.fullDisplaySpan.status != kSentrySpanStatusDeadlineExceeded) {
        return;
    }

    self.fullDisplaySpan.timestamp = self.initialDisplaySpan.timestamp;
    self.fullDisplaySpan.spanDescription =
        [NSString stringWithFormat:@"%@ - Expired", self.fullDisplaySpan.spanDescription];
}

@end
#endif
