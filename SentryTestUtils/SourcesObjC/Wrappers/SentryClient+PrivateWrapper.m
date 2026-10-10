#import "SentryClient+Private.h"
#import "SentrySwift.h"
#import "Wrappers/SentryClient+PrivateWrapper.h"

@implementation SentryTestSessionDelegateWrapper
- (SentrySession *)incrementSessionErrors
{
    return [self wrapper_incrementSessionErrors];
}

- (id)wrapper_incrementSessionErrors
{
    return nil;
}
@end
