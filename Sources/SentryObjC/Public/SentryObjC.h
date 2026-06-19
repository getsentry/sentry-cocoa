#import <Foundation/Foundation.h>

// Platform detection and shared macros
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

// --- Enums (no dependencies) ---
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCAttachmentType.h"
#    import "SentryObjCFeedbackSource.h"
#    import "SentryObjCLastRunStatus.h"
#    import "SentryObjCLevel.h"
#    import "SentryObjCLogLevel.h"
#    import "SentryObjCReplayQuality.h"
#    import "SentryObjCSampleDecision.h"
#    import "SentryObjCSpanStatus.h"
#    import "SentryObjCTransactionNameSource.h"
#else
#    import <SentryObjC/SentryObjCAttachmentType.h>
#    import <SentryObjC/SentryObjCFeedbackSource.h>
#    import <SentryObjC/SentryObjCLastRunStatus.h>
#    import <SentryObjC/SentryObjCLevel.h>
#    import <SentryObjC/SentryObjCLogLevel.h>
#    import <SentryObjC/SentryObjCReplayQuality.h>
#    import <SentryObjC/SentryObjCSampleDecision.h>
#    import <SentryObjC/SentryObjCSpanStatus.h>
#    import <SentryObjC/SentryObjCTransactionNameSource.h>
#endif

// --- Data carriers ---
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCAttributeContent.h"
#    import "SentryObjCMetric.h"
#    import "SentryObjCMetricValue.h"
#    import "SentryObjCRedactRegionType.h"
#    import "SentryObjCUnit.h"
#else
#    import <SentryObjC/SentryObjCAttributeContent.h>
#    import <SentryObjC/SentryObjCMetric.h>
#    import <SentryObjC/SentryObjCMetricValue.h>
#    import <SentryObjC/SentryObjCRedactRegionType.h>
#    import <SentryObjC/SentryObjCUnit.h>
#endif

// --- Leaf types (no wrapper dependencies) ---
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDebugMeta.h"
#    import "SentryObjCFrame.h"
#    import "SentryObjCGeo.h"
#    import "SentryObjCHttpStatusCodeRange.h"
#    import "SentryObjCId.h"
#    import "SentryObjCMeasurementUnit.h"
#    import "SentryObjCMechanismContext.h"
#    import "SentryObjCMessage.h"
#    import "SentryObjCNSError.h"
#    import "SentryObjCRequest.h"
#    import "SentryObjCSpanId.h"
#    import "SentryObjCTraceHeader.h"
#else
#    import <SentryObjC/SentryObjCDebugMeta.h>
#    import <SentryObjC/SentryObjCFrame.h>
#    import <SentryObjC/SentryObjCGeo.h>
#    import <SentryObjC/SentryObjCHttpStatusCodeRange.h>
#    import <SentryObjC/SentryObjCId.h>
#    import <SentryObjC/SentryObjCMeasurementUnit.h>
#    import <SentryObjC/SentryObjCMechanismContext.h>
#    import <SentryObjC/SentryObjCMessage.h>
#    import <SentryObjC/SentryObjCNSError.h>
#    import <SentryObjC/SentryObjCRequest.h>
#    import <SentryObjC/SentryObjCSpanId.h>
#    import <SentryObjC/SentryObjCTraceHeader.h>
#endif

// --- Composite types (depend on leaf types) ---
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCAttachment.h"
#    import "SentryObjCBreadcrumb.h"
#    import "SentryObjCException.h"
#    import "SentryObjCMechanism.h"
#    import "SentryObjCStacktrace.h"
#    import "SentryObjCThread.h"
#    import "SentryObjCUser.h"
#else
#    import <SentryObjC/SentryObjCAttachment.h>
#    import <SentryObjC/SentryObjCBreadcrumb.h>
#    import <SentryObjC/SentryObjCException.h>
#    import <SentryObjC/SentryObjCMechanism.h>
#    import <SentryObjC/SentryObjCStacktrace.h>
#    import <SentryObjC/SentryObjCThread.h>
#    import <SentryObjC/SentryObjCUser.h>
#endif

// --- Span context hierarchy ---
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCSpanContext.h"
#    import "SentryObjCTransactionContext.h"
#else
#    import <SentryObjC/SentryObjCSpanContext.h>
#    import <SentryObjC/SentryObjCTransactionContext.h>
#endif

// --- Higher-level types ---
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCEvent.h"
#    import "SentryObjCFeedback.h"
#    import "SentryObjCSamplingContext.h"
#    import "SentryObjCScope.h"
#    import "SentryObjCSpan.h"
#    import "SentryObjCTraceContext.h"
#else
#    import <SentryObjC/SentryObjCEvent.h>
#    import <SentryObjC/SentryObjCFeedback.h>
#    import <SentryObjC/SentryObjCSamplingContext.h>
#    import <SentryObjC/SentryObjCScope.h>
#    import <SentryObjC/SentryObjCSpan.h>
#    import <SentryObjC/SentryObjCTraceContext.h>
#endif

// --- Attribute and log types ---
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCAttribute.h"
#    import "SentryObjCLog.h"
#    import "SentryObjCLogger.h"
#else
#    import <SentryObjC/SentryObjCAttribute.h>
#    import <SentryObjC/SentryObjCLog.h>
#    import <SentryObjC/SentryObjCLogger.h>
#endif

// --- Configuration ---
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCExperimentalOptions.h"
#    import "SentryObjCOptions.h"
#    import "SentryObjCReplayOptions.h"
#    import "SentryObjCUserFeedbackConfiguration.h"
#    import "SentryObjCUserFeedbackFormConfiguration.h"
#    import "SentryObjCUserFeedbackFormElementOutlineStyle.h"
#    import "SentryObjCUserFeedbackThemeConfiguration.h"
#else
#    import <SentryObjC/SentryObjCExperimentalOptions.h>
#    import <SentryObjC/SentryObjCOptions.h>
#    import <SentryObjC/SentryObjCReplayOptions.h>
#    import <SentryObjC/SentryObjCUserFeedbackConfiguration.h>
#    import <SentryObjC/SentryObjCUserFeedbackFormConfiguration.h>
#    import <SentryObjC/SentryObjCUserFeedbackFormElementOutlineStyle.h>
#    import <SentryObjC/SentryObjCUserFeedbackThemeConfiguration.h>
#endif

// --- API surfaces ---
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCFeedbackApi.h"
#    import "SentryObjCFeedbackForm.h"
#    import "SentryObjCMetricsApi.h"
#    import "SentryObjCReplayApi.h"
#else
#    import <SentryObjC/SentryObjCFeedbackApi.h>
#    import <SentryObjC/SentryObjCFeedbackForm.h>
#    import <SentryObjC/SentryObjCMetricsApi.h>
#    import <SentryObjC/SentryObjCReplayApi.h>
#endif

// --- Internal API (hybrid SDK structured API) ---
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCInternalApi.h"
#    import "SentryObjCInternalBreadcrumbApi.h"
#    import "SentryObjCInternalDebugApi.h"
#    import "SentryObjCInternalEnvelopeApi.h"
#    import "SentryObjCInternalPerformanceApi.h"
#    import "SentryObjCInternalScreenshotApi.h"
#    import "SentryObjCInternalSdkApi.h"
#    import "SentryObjCInternalUserApi.h"
#else
#    import <SentryObjC/SentryObjCInternalApi.h>
#    import <SentryObjC/SentryObjCInternalBreadcrumbApi.h>
#    import <SentryObjC/SentryObjCInternalDebugApi.h>
#    import <SentryObjC/SentryObjCInternalEnvelopeApi.h>
#    import <SentryObjC/SentryObjCInternalPerformanceApi.h>
#    import <SentryObjC/SentryObjCInternalScreenshotApi.h>
#    import <SentryObjC/SentryObjCInternalSdkApi.h>
#    import <SentryObjC/SentryObjCInternalUserApi.h>
#endif

// --- Envelope types (SPI for hybrid SDKs) ---
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCEnvelope.h"
#    import "SentryObjCEnvelopeHeader.h"
#    import "SentryObjCEnvelopeItem.h"
#else
#    import <SentryObjC/SentryObjCEnvelope.h>
#    import <SentryObjC/SentryObjCEnvelopeHeader.h>
#    import <SentryObjC/SentryObjCEnvelopeItem.h>
#endif

// --- Entry points ---
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCClient.h"
#    import "SentryObjCHub.h"
#    import "SentryObjCPrivateSDKOnly.h"
#    import "SentryObjCSDK.h"
#else
#    import <SentryObjC/SentryObjCClient.h>
#    import <SentryObjC/SentryObjCHub.h>
#    import <SentryObjC/SentryObjCPrivateSDKOnly.h>
#    import <SentryObjC/SentryObjCSDK.h>
#endif
