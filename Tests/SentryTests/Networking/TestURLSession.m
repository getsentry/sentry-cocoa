#import "TestURLSession.h"
#import "SentryCurrentDateProvider.h"
#import "SentryDependencyContainer.h"

@implementation TestURLSession

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (instancetype)init
{
    self = [super init];
    return self;
}
#pragma clang diagnostic pop

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
{
    self.lastDataTask = [[URLSessionDataTaskMock alloc] initWithRequest:request];
    return self.lastDataTask;
}

- (void)invalidateAndCancel
{
    self.invalidateAndCancelDate = [SentryDependencyContainer.sharedInstance.dateProvider date];
}

@end
