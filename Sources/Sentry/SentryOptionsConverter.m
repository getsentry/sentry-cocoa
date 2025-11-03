#import "SentryOptionsConverter.h"
#import "SentryOptionsInternal.h"
#import "SentrySwift.h"

@implementation SentryOptionsConverter

+ (SentryOptions *)fromInternal:(SentryOptionsInternal *)internalOptions
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.dsn = internalOptions.dsn;
    return options;
}

@end
