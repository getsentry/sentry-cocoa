#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryBaggageHeaderField = @"baggage";
static NSString *const SentryTraceHeaderField = @"sentry-trace";
static NSString *const SentrySpanTypeTrace = @"trace";

/// Description of a Mach kernel return code. Swift calls this method because visionOS Swift
/// cannot call the C++ helper directly.
@interface SentryKernelErrorDescription : NSObject

+ (NSString *)stringForKernelReturnCode:(int32_t)code;

@end

NS_ASSUME_NONNULL_END

// C functions stay out of the Swift private module. visionOS Swift cannot call them.
#if !__building_module(_SentryPrivate)
#    import "SentryError.h"
#    import "SentrySpanStatus.h"

NS_ASSUME_NONNULL_BEGIN
#    ifdef __cplusplus
extern "C" {
#    endif
NSError *sentry_errorWithDescription(SentryError error, NSString *description);
NSError *sentry_errorWithUnderlyingError(
    SentryError error, NSString *description, NSError *underlyingError);
NSError *sentry_errorWithException(
    SentryError error, NSString *description, NSException *exception);
NSError *sentry_errorWithKernelError(
    SentryError error, NSString *description, kern_return_t kernelErrorCode);
NSString *sentry_spanStatusName(SentrySpanStatus status);
#    ifdef __cplusplus
}
#    endif
NS_ASSUME_NONNULL_END
#endif // !__building_module(_SentryPrivate)
