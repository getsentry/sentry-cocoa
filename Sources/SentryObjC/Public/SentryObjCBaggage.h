#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * Provides baggage HTTP header metadata.
 */
@interface SentryObjCBaggage : NSObject
SENTRY_NO_INIT

/// The name of the baggage HTTP header.
@property (class, nonatomic, readonly, copy) NSString *httpHeaderField;

@end

NS_ASSUME_NONNULL_END
