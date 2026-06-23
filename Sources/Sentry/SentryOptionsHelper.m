#import "SentryOptionsHelper.h"
#import "SentryInternalDefines.h"
#import "SentryOptionsInternal.h"

@implementation SentryOptionsHelper

+ (nullable SentryOptions *)optionsWithDictionary:(NSDictionary<NSString *, id> *)options
                                 didFailWithError:(NSError *_Nullable *_Nullable)error
{
    return [SentryOptionsInternal initWithDict:options didFailWithError:error];
}

@end
