#if SDK_V10
#    import <Foundation/Foundation.h>
#    if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#        import "SentryObjCEvent.h"
#    else
#        import <SentryObjC/SentryObjCEvent.h>
#    endif

NS_ASSUME_NONNULL_BEGIN

/// A transaction event.
@interface SentryObjCTransaction : SentryObjCEvent
SENTRY_NO_INIT
@end

NS_ASSUME_NONNULL_END
#endif // SDK_V10
