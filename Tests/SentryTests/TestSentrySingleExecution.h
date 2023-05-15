#import "SentrySingleExecution.h"
@interface
SentrySingleExecution ()

@property (nonatomic, strong) void (^willSkip)(void);

@property (nonatomic, strong) void (^willExecute)(void);

@end
