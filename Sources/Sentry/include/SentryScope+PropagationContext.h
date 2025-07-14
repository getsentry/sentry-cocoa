#import "SentryScope.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryScope ()

// This is a workaround to make the traceId available in the Swift layer. 
// Can't expose the SentryId directly for some reason.
@property (nonatomic, readonly) NSString *propagationContextTraceIdString;

@end

NS_ASSUME_NONNULL_END
