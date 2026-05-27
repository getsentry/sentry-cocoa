#import <Foundation/Foundation.h>

// Platform detection and shared macros
#import "SentryObjCDefines.h"

// --- Enums (no dependencies) ---
#import "SentryObjCAttachmentType.h"
#import "SentryObjCFeedbackSource.h"
#import "SentryObjCLastRunStatus.h"
#import "SentryObjCLevel.h"
#import "SentryObjCLogLevel.h"
#import "SentryObjCReplayQuality.h"
#import "SentryObjCSampleDecision.h"
#import "SentryObjCSpanStatus.h"
#import "SentryObjCTransactionNameSource.h"

// --- Data carriers ---
#import "SentryObjCAttributeContent.h"
#import "SentryObjCMetric.h"
#import "SentryObjCMetricValue.h"
#import "SentryObjCRedactRegionType.h"
#import "SentryObjCUnit.h"

// --- Leaf types (no wrapper dependencies) ---
#import "SentryObjCDebugMeta.h"
#import "SentryObjCFrame.h"
#import "SentryObjCGeo.h"
#import "SentryObjCHttpStatusCodeRange.h"
#import "SentryObjCId.h"
#import "SentryObjCMeasurementUnit.h"
#import "SentryObjCMechanismContext.h"
#import "SentryObjCMessage.h"
#import "SentryObjCNSError.h"
#import "SentryObjCRequest.h"
#import "SentryObjCSpanId.h"
#import "SentryObjCTraceHeader.h"

// --- Composite types (depend on leaf types) ---
#import "SentryObjCAttachment.h"
#import "SentryObjCBreadcrumb.h"
#import "SentryObjCException.h"
#import "SentryObjCMechanism.h"
#import "SentryObjCStacktrace.h"
#import "SentryObjCThread.h"
#import "SentryObjCUser.h"

// --- Span context hierarchy ---
#import "SentryObjCSpanContext.h"
#import "SentryObjCTransactionContext.h"

// --- Higher-level types ---
#import "SentryObjCEvent.h"
#import "SentryObjCFeedback.h"
#import "SentryObjCSamplingContext.h"
#import "SentryObjCScope.h"
#import "SentryObjCSpan.h"
#import "SentryObjCTraceContext.h"

// --- Attribute and log types ---
#import "SentryObjCAttribute.h"
#import "SentryObjCLog.h"
#import "SentryObjCLogger.h"

// --- Configuration ---
#import "SentryObjCExperimentalOptions.h"
#import "SentryObjCOptions.h"
#import "SentryObjCReplayOptions.h"

// --- API surfaces ---
#import "SentryObjCFeedbackApi.h"
#import "SentryObjCMetricsApi.h"
#import "SentryObjCReplayApi.h"

// --- Envelope types (SPI for hybrid SDKs) ---
#import "SentryObjCEnvelope.h"
#import "SentryObjCEnvelopeHeader.h"
#import "SentryObjCEnvelopeItem.h"

// --- Entry points ---
#import "SentryObjCClient.h"
#import "SentryObjCHub.h"
#import "SentryObjCPrivateSDKOnly.h"
#import "SentryObjCSDK.h"
