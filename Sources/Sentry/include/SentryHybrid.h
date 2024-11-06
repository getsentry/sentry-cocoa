#if __has_include(<Sentry/PrivateSentrySDKOnly.h>)
#    import <Sentry/PrivateSentrySDKOnly.h>
#else
#    import "PrivateSentrySDKOnly.h"
#endif

#import "PrivatesHeader.h"
#import "SentryAppStartMeasurement.h"
#import "SentryBinaryImageCache.h"
#import "SentryBreadcrumb+Private.h"
#import "SentryDebugImageProvider+HybridSDKs.h"
#import "SentryDependencyContainer.h"
#import "SentryEnvelope.h"
#import "SentryEnvelopeItemType.h"
#import "SentryFormatter.h"
#import "SentryFramesTracker.h"
#import "SentryOptions+HybridSDKs.h"
#import "SentryScreenFrames.h"
#import "SentrySessionReplayIntegration-Hybrid.h"
#import "SentrySwizzle.h"
#import "SentryUser+Private.h"

#import "SentryInternalSerializable.h"
