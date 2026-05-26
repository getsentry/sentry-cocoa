#import <Foundation/Foundation.h>

// Platform detection and shared macros
#import <SentryObjC/SentryObjCDefines.h>

// --- Enums (no dependencies) ---
#import <SentryObjC/SentryObjCAttachmentType.h>
#import <SentryObjC/SentryObjCFeedbackSource.h>
#import <SentryObjC/SentryObjCLastRunStatus.h>
#import <SentryObjC/SentryObjCLevel.h>
#import <SentryObjC/SentryObjCLogLevel.h>
#import <SentryObjC/SentryObjCReplayQuality.h>
#import <SentryObjC/SentryObjCSampleDecision.h>
#import <SentryObjC/SentryObjCSpanStatus.h>
#import <SentryObjC/SentryObjCTransactionNameSource.h>

// --- Data carriers ---
#import <SentryObjC/SentryObjCAttributeContent.h>
#import <SentryObjC/SentryObjCMetric.h>
#import <SentryObjC/SentryObjCMetricValue.h>
#import <SentryObjC/SentryObjCRedactRegionType.h>
#import <SentryObjC/SentryObjCUnit.h>

// --- Leaf types (no wrapper dependencies) ---
#import <SentryObjC/SentryObjCDebugMeta.h>
#import <SentryObjC/SentryObjCFrame.h>
#import <SentryObjC/SentryObjCGeo.h>
#import <SentryObjC/SentryObjCHttpStatusCodeRange.h>
#import <SentryObjC/SentryObjCId.h>
#import <SentryObjC/SentryObjCMeasurementUnit.h>
#import <SentryObjC/SentryObjCMechanismContext.h>
#import <SentryObjC/SentryObjCMessage.h>
#import <SentryObjC/SentryObjCNSError.h>
#import <SentryObjC/SentryObjCRequest.h>
#import <SentryObjC/SentryObjCSpanId.h>
#import <SentryObjC/SentryObjCTraceHeader.h>

// --- Composite types (depend on leaf types) ---
#import <SentryObjC/SentryObjCAttachment.h>
#import <SentryObjC/SentryObjCBreadcrumb.h>
#import <SentryObjC/SentryObjCException.h>
#import <SentryObjC/SentryObjCMechanism.h>
#import <SentryObjC/SentryObjCStacktrace.h>
#import <SentryObjC/SentryObjCThread.h>
#import <SentryObjC/SentryObjCUser.h>

// --- Span context hierarchy ---
#import <SentryObjC/SentryObjCSpanContext.h>
#import <SentryObjC/SentryObjCTransactionContext.h>

// --- Higher-level types ---
#import <SentryObjC/SentryObjCEvent.h>
#import <SentryObjC/SentryObjCFeedback.h>
#import <SentryObjC/SentryObjCSamplingContext.h>
#import <SentryObjC/SentryObjCScope.h>
#import <SentryObjC/SentryObjCSpan.h>
#import <SentryObjC/SentryObjCTraceContext.h>

// --- Attribute and log types ---
#import <SentryObjC/SentryObjCAttribute.h>
#import <SentryObjC/SentryObjCLog.h>
#import <SentryObjC/SentryObjCLogger.h>

// --- Configuration ---
#import <SentryObjC/SentryObjCExperimentalOptions.h>
#import <SentryObjC/SentryObjCOptions.h>
#import <SentryObjC/SentryObjCReplayOptions.h>

// --- API surfaces ---
#import <SentryObjC/SentryObjCFeedbackApi.h>
#import <SentryObjC/SentryObjCMetricsApi.h>
#import <SentryObjC/SentryObjCReplayApi.h>

// --- Envelope types (SPI for hybrid SDKs) ---
#import <SentryObjC/SentryObjCEnvelope.h>
#import <SentryObjC/SentryObjCEnvelopeHeader.h>
#import <SentryObjC/SentryObjCEnvelopeItem.h>

// --- Entry points ---
#import <SentryObjC/SentryObjCClient.h>
#import <SentryObjC/SentryObjCHub.h>
#import <SentryObjC/SentryObjCPrivateSDKOnly.h>
#import <SentryObjC/SentryObjCSDK.h>
