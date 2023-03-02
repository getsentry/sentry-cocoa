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
@property (nonatomic, strong) NSDate *fullDisplay;
@property (nonatomic, strong) NSString *controllerName;
@property (nonatomic) BOOL waitFullDisplay;

@end

@implementation SentryTimeToDisplayTracker

- (instancetype)initForController:(UIViewController *)controller
               waitForFullDisplay:(BOOL)waitFullDisplay
{
    if (self = [super init]) {
        self.startDate = [SentryCurrentDate date];
        self.controllerName = [SwiftDescriptor getObjectClassName:controller];
        self.waitFullDisplay = waitFullDisplay;
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

    if (self.fullDisplay != nil &&
        [self.fullDisplay compare:self.initialDisplaySpan.timestamp] == NSOrderedAscending) {
        self.fullDisplay = self.initialDisplaySpan.timestamp;
    }

    if (!self.waitFullDisplay || self.fullDisplay != nil) {
        // If this class is waiting for a full display, we don't finish the TTID span
        // because this will make the tracer wait for its children which gives the user more time to
        // report full display, since SentryTracer have a dead line timeout, eventually it will be
        // finished.
        [self.initialDisplaySpan finish];
    }
}

- (void)reportFullDisplay
{
    if (self.waitFullDisplay) {
        self.fullDisplay = [SentryCurrentDate date];

        if (self.waitFullDisplay && self.initialDisplaySpan.timestamp != nil) {
            [self.initialDisplaySpan finish];
        }
    }
}

- (void)stopWaitingFullDisplay
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
    if (self.fullDisplay) {
        SentrySpan *ttfd = creationCallback(SentrySpanOperationUILoadFullDisplay,[NSString stringWithFormat:@"%@ full display",
                                                                                  self.controllerName]);

        ttfd.startTimestamp = self.startDate;
        ttfd.timestamp = self.fullDisplay;
        ttfd.status = kSentrySpanStatusOk;

        return @[ ttfd ];
    }

    return @[];
}

@end
#endif
