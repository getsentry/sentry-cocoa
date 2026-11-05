#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryBaggageHeaderField = @"baggage";
static NSString *const SentryTraceHeaderField = @"sentry-trace";
static NSString *const SentrySpanTypeTrace = @"trace";

#ifdef __cplusplus
extern "C" {
#endif
NSString *sentry_kernelErrorDescription(int32_t code);
#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END

// These helpers stay out of the Swift module so Swift call sites use SentryError.nsError
// and SentrySpanStatus.name. sentry_spanStatusName is implemented in Swift.
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
