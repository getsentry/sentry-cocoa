#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#import "SentryTransactionNameSource.h"

// Pure-ObjC types from main SDK (re-exported, single source of truth).
// Xcode frameworks expose them under `<Sentry/...>`; SPM exposes them via -I on
// the dependency's publicHeadersPath, so we detect with __has_include and fall
// back to the quoted form.
#if __has_include(<Sentry/SentryAppStartMeasurement.h>)
#    import <Sentry/SentryAppStartMeasurement.h>
#    import <Sentry/SentryAttachment.h>
#    import <Sentry/SentryBaggage.h>
#    import <Sentry/SentryBreadcrumb.h>
#    import <Sentry/SentryDebugMeta.h>
#    import <Sentry/SentryError.h>
#    import <Sentry/SentryEvent.h>
#    import <Sentry/SentryException.h>
#    import <Sentry/SentryFrame.h>
#    import <Sentry/SentryGeo.h>
#    import <Sentry/SentryHttpStatusCodeRange.h>
#    import <Sentry/SentryId.h>
#    import <Sentry/SentryLevel.h>
#    import <Sentry/SentryMeasurementUnit.h>
#    import <Sentry/SentryMechanism.h>
#    import <Sentry/SentryMechanismContext.h>
#    import <Sentry/SentryMessage.h>
#    import <Sentry/SentryNSError.h>
#    import <Sentry/SentryReplayApi.h>
#    import <Sentry/SentryRequest.h>
#    import <Sentry/SentrySampleDecision.h>
#    import <Sentry/SentrySamplingContext.h>
#    import <Sentry/SentryScope.h>
#    import <Sentry/SentrySerializable.h>
#    import <Sentry/SentrySpanContext.h>
#    import <Sentry/SentrySpanId.h>
#    import <Sentry/SentrySpanStatus.h>
#    import <Sentry/SentryStacktrace.h>
#    import <Sentry/SentryThread.h>
#    import <Sentry/SentryTraceContext.h>
#    import <Sentry/SentryTraceHeader.h>
#    import <Sentry/SentryTransactionContext.h>
#    import <Sentry/SentryUser.h>
#else
#    import "SentryAppStartMeasurement.h"
#    import "SentryAttachment.h"
#    import "SentryBaggage.h"
#    import "SentryBreadcrumb.h"
#    import "SentryDebugMeta.h"
#    import "SentryError.h"
#    import "SentryEvent.h"
#    import "SentryException.h"
#    import "SentryFrame.h"
#    import "SentryGeo.h"
#    import "SentryHttpStatusCodeRange.h"
#    import "SentryId.h"
#    import "SentryLevel.h"
#    import "SentryMeasurementUnit.h"
#    import "SentryMechanism.h"
#    import "SentryMechanismContext.h"
#    import "SentryMessage.h"
#    import "SentryNSError.h"
#    import "SentryReplayApi.h"
#    import "SentryRequest.h"
#    import "SentrySampleDecision.h"
#    import "SentrySamplingContext.h"
#    import "SentryScope.h"
#    import "SentrySerializable.h"
#    import "SentrySpanContext.h"
#    import "SentrySpanId.h"
#    import "SentrySpanStatus.h"
#    import "SentryStacktrace.h"
#    import "SentryThread.h"
#    import "SentryTraceContext.h"
#    import "SentryTraceHeader.h"
#    import "SentryTransactionContext.h"
#    import "SentryUser.h"
#endif
#import "SentrySpan.h"

// Swift @objc types
#import "SentryAttribute.h"
#import "SentryExperimentalOptions.h"
#import "SentryFeedback.h"
#import "SentryFeedbackSource.h"
#import "SentryLog.h"
#import "SentryLogLevel.h"
#import "SentryLogger.h"
#import "SentryOptions.h"
#import "SentryReplayOptions.h"
#import "SentrySDK.h"

// Envelope types (SPI for hybrid SDKs)
#import "PrivateSentrySDKOnly.h"
#import "SentryEnvelope.h"
#import "SentryEnvelopeHeader.h"
#import "SentryEnvelopeItem.h"

// Protocols / facades for Swift-only APIs (stay in SentryObjC — behavior layer)
#import "SentryMetricsApi.h"

// Frozen public ObjC data carriers (from SentryObjCTypes).
// Xcode frameworks expose them under `<SentryObjCTypes/...>`; SPM exposes the
// headers via -I on the dependency's publicHeadersPath (no framework wrapper),
// so we detect with __has_include and fall back to the quoted form.
#if __has_include(<SentryObjCTypes/SentryObjCAttributeContent.h>)
#    import <SentryObjCTypes/SentryObjCAttributeContent.h>
#    import <SentryObjCTypes/SentryObjCMetric.h>
#    import <SentryObjCTypes/SentryObjCMetricValue.h>
#    import <SentryObjCTypes/SentryObjCRedactRegionType.h>
#    import <SentryObjCTypes/SentryObjCUnit.h>
#else
#    import "SentryObjCAttributeContent.h"
#    import "SentryObjCMetric.h"
#    import "SentryObjCMetricValue.h"
#    import "SentryObjCRedactRegionType.h"
#    import "SentryObjCUnit.h"
#endif
