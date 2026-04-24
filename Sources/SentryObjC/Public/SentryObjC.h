#import <Foundation/Foundation.h>

#import "SentryDefines.h"

// Re-declared ObjC types (standalone headers, no transitive imports from Sentry)
#import "SentryAppStartMeasurement.h"
#import "SentryAttachment.h"
#import "SentryBaggage.h"
#import "SentryBreadcrumb.h"
#import "SentryDebugMeta.h"
#import "SentryError.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentryFrame.h"
#import "SentryGeo.h"
#import "SentryHttpStatusCodeRange.h"
#import "SentryId.h"
#import "SentryLevel.h"
#import "SentryMeasurementUnit.h"
#import "SentryMechanism.h"
#import "SentryMechanismContext.h"
#import "SentryMessage.h"
#import "SentryNSError.h"
#import "SentryReplayApi.h"
#import "SentryRequest.h"
#import "SentrySampleDecision.h"
#import "SentrySamplingContext.h"
#import "SentryScope.h"
#import "SentrySerializable.h"
#import "SentrySpan.h"
#import "SentrySpanContext.h"
#import "SentrySpanId.h"
#import "SentrySpanStatus.h"
#import "SentryStacktrace.h"
#import "SentryThread.h"
#import "SentryTraceContext.h"
#import "SentryTraceHeader.h"
#import "SentryTransactionContext.h"
#import "SentryTransactionNameSource.h"
#import "SentryUser.h"

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

// Frozen public ObjC data carriers (from SentryObjCTypes)
#import <SentryObjCTypes/SentryObjCAttributeContent.h>
#import <SentryObjCTypes/SentryObjCMetric.h>
#import <SentryObjCTypes/SentryObjCMetricValue.h>
#import <SentryObjCTypes/SentryObjCRedactRegionType.h>
#import <SentryObjCTypes/SentryObjCUnit.h>
