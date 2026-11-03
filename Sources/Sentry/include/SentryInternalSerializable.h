#import "SentryBreadcrumb.h"
#import "SentryDebugMeta.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentryFrame.h"
#import "SentryGeo.h"
#import "SentryMechanism.h"
#import "SentryMechanismContext.h"
#import "SentryMessage.h"
#import "SentryNSError.h"
#import "SentryRequest.h"
#import "SentryScope.h"
#import "SentrySpanContext.h"
#import "SentryStacktrace.h"
#import "SentryThread.h"
#import "SentryTraceContext.h"
#import "SentryUser.h"
#if __has_include(<Sentry/SentryDefines.h>)
#    import <Sentry/SentryDefines.h>
#else
#    import "SentryDefines.h"
#endif

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// SDK-internal dictionary serialization. Not part of the public or hybrid SDK API.
@protocol SentryInternalSerializable <NSObject>
SENTRY_NO_INIT

- (NSDictionary<NSString *, id> *)serialize;

@end

@interface SentryDebugMeta () <SentryInternalSerializable>
@end

@interface SentryGeo () <SentryInternalSerializable>
@end

@interface SentryException () <SentryInternalSerializable>
@end

@interface SentryEvent () <SentryInternalSerializable>
@end

@interface SentryRequest () <SentryInternalSerializable>
@end

@interface SentryUser () <SentryInternalSerializable>
@end

@interface SentryStacktrace () <SentryInternalSerializable>
@end

@interface SentryNSError () <SentryInternalSerializable>
@end

@interface SentryMechanism () <SentryInternalSerializable>
@end

@interface SentryScope () <SentryInternalSerializable>
@end

@interface SentrySpanContext () <SentryInternalSerializable>
@end

@interface SentryBreadcrumb () <SentryInternalSerializable>
@end

@interface SentryTraceContext () <SentryInternalSerializable>
@end

@interface SentryThread () <SentryInternalSerializable>
@end

@interface SentryFrame () <SentryInternalSerializable>
@end

@interface SentryMechanismContext () <SentryInternalSerializable>
@end

@interface SentryMessage () <SentryInternalSerializable>
@end

NS_ASSUME_NONNULL_END
