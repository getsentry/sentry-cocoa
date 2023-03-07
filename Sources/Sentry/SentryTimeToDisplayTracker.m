#import "SentryTimeToDisplayTracker.h"
#import "SentryCurrentDate.h"
#import "SentrySpan.h"
#import "SentrySpanContext.h"
#import "SentrySpanId.h"
#import "SentrySpanOperations.h"
#import "SentrySwift.h"

#if SENTRY_HAS_UIKIT

@interface
SentryTimeToDisplayTracker ()

@property (nonatomic, strong) NSDate *startDate;
@property (nonatomic, strong) SentrySpan *initialDisplaySpan;
@property (nonatomic, strong) NSDate *fullDisplayDate;
@property (nonatomic, strong) NSString *controllerName;
@property (nonatomic) BOOL waitForFullDisplay;

@end

@implementation SentryTimeToDisplayTracker

- (instancetype)initForController:(UIViewController *)controller
               waitForFullDisplay:(BOOL)waitForFullDisplay
{
    if (self = [super init]) {
        self.startDate = [SentryCurrentDate date];
        self.controllerName = [SwiftDescriptor getObjectClassName:controller];
        self.waitForFullDisplay = waitForFullDisplay;
    }
    return self;
}

- (void)installForTracer:(SentryTracer *)tracer
{
    self.initialDisplaySpan =
        [tracer startChildWithOperation:SentrySpanOperationUILoadInitialDisplay
                            description:[NSString stringWithFormat:@"%@ initial display",
                                                  self.controllerName]];
}

- (void)reportInitialDisplay
{
    if (self.initialDisplaySpan.timestamp != nil) {
        return;
    }

    self.initialDisplaySpan.timestamp = [SentryCurrentDate date];

    if (self.fullDisplayDate != nil &&
        [self.fullDisplayDate compare:self.initialDisplaySpan.timestamp] == NSOrderedAscending) {
        self.fullDisplayDate = self.initialDisplaySpan.timestamp;
    }

    if (!self.waitForFullDisplay || self.fullDisplayDate != nil) {
        // If this class is waiting for a full display, we don't finish the TTID span
        // because this will make the tracer wait for its children which gives the user more time to
        // report full display, since SentryTracer have a dead line timeout, eventually it will be
        // finished.
        [self.initialDisplaySpan finish];
    }
}

- (void)reportFullyDisplayed
{
    if (self.waitForFullDisplay) {
        self.fullDisplayDate = [SentryCurrentDate date];

        if (self.waitForFullDisplay && self.initialDisplaySpan.timestamp != nil) {
            [self.initialDisplaySpan finish];
        }
    }
}

- (void)stopWaitingForFullDisplay
{
    if (self.initialDisplaySpan && !self.initialDisplaySpan.isFinished) {
        [self.initialDisplaySpan finish];
    }
}

- (void)tracerDidTimeout
{
    // SentryTracer deadline timeout fired,
    // initial display span needs to be finished.
    if (!self.initialDisplaySpan.isFinished) {
        [self.initialDisplaySpan finish];
    }
}

- (NSArray<id<SentrySpan>> *)tracerAdditionalSpan:(SpanCreationCallback)creationCallback
{
    if (self.fullDisplayDate) {
        SentrySpan *ttfd = creationCallback(SentrySpanOperationUILoadFullDisplay,
            [NSString stringWithFormat:@"%@ full display", self.controllerName]);

        ttfd.startTimestamp = self.startDate;
        ttfd.timestamp = self.fullDisplayDate;
        ttfd.status = kSentrySpanStatusOk;

        return @[ ttfd ];
    }

    return @[];
}

@end
#endif
