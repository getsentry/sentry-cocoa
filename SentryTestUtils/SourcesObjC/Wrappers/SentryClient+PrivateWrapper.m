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
    // Intentionally returns nil: Swift test delegates override this type-erased bridge method
    // to provide session behavior when the original selector cannot be overridden under SwiftPM.
    return nil;
}
@end
