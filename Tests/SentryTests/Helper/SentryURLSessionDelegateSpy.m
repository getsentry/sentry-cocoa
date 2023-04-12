#import "SentryURLSessionDelegateSpy.h"

@implementation SentryURLSessionDelegateSpy

- (void)URLSession:(NSURLSession *)session
    didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
      completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition,
                            NSURLCredential *_Nullable))completionHandler
{
    self.delegateCallback();

    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

@end
