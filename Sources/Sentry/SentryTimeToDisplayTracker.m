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

@property (nonatomic, strong) SentrySpan *initialDisplaySpan;
@property (nonatomic, strong) SentrySpan *fullDisplaySpan;
@property (nonatomic, strong) NSString *controllerName;
@property (nonatomic) BOOL waitForFullDisplay;

@end

@implementation SentryTimeToDisplayTracker

- (instancetype)initForController:(UIViewController *)controller
               waitForFullDisplay:(BOOL)waitForFullDisplay
{
    if (self = [super init]) {
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

    if (self.waitForFullDisplay) {
        self.fullDisplaySpan = [tracer startChildWithOperation:SentrySpanOperationUILoadFullDisplay description:[NSString stringWithFormat:@"%@ full display", self.controllerName]];
    }
}

- (void)reportInitialDisplay
{
    if (self.initialDisplaySpan.timestamp != nil) {
        return;
    }

    self.initialDisplaySpan.timestamp = [SentryCurrentDate date];

    if (self.fullDisplaySpan.timestamp != nil &&
        [self.fullDisplaySpan.timestamp compare:self.initialDisplaySpan.timestamp] == NSOrderedAscending) {
        self.fullDisplaySpan.timestamp = self.initialDisplaySpan.timestamp;
    }
    [self.initialDisplaySpan finish];
}

- (void)reportFullyDisplayed
{
    if (self.waitForFullDisplay) {
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
}

- (NSArray<id<SentrySpan>> *)tracerAdditionalSpan:(SpanCreationCallback)creationCallback
{
    return @[];
}

@end
#endif
