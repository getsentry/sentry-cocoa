#import "SentrySingleExecution.h"

#if TEST || TESTCI
//We dont need this extra code for release
@interface SentrySingleExecution ()

@property (nonatomic, strong) void (^willSkip)(void);
@property (nonatomic, strong) void (^willExecute)(void);


@end

#define CALL_FOR_TEST(BLOCK) if (BLOCK != nil) { BLOCK(); }
#else
#define CALL_FOR_TEST(...)
#endif

@implementation SentrySingleExecution

- (BOOL)standaloneExecution:(void (^)(void))block {
    if (_isRunning) {
        CALL_FOR_TEST(self.willSkip);
        return NO;
    }
    @synchronized (self) {
        if (_isRunning) {
            CALL_FOR_TEST(self.willSkip);
            return NO;
        }
        _isRunning = YES;
    }

    CALL_FOR_TEST(self.willExecute);
    block();

    return YES;
}

@end
