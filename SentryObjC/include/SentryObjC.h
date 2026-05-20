// Umbrella header for the `SentryObjC` SPM target. Importing this single
// header brings in every public class and enum mirroring the Swift
// `SentryObjCCompat` module. Non-modular ObjC consumers can either #import
// this umbrella or pick out individual headers as needed.

// Enums
#import "SOCSentryAttachmentType.h"
#import "SOCSentryFeedbackSource.h"
#import "SOCSentryLastRunStatus.h"
#import "SOCSentryLevel.h"
#import "SOCSentrySampleDecision.h"
#import "SOCSentrySpanStatus.h"
#import "SOCSentryTransactionNameSource.h"

// Leaf classes
#import "SOCSentryDebugMeta.h"
#import "SOCSentryDsn.h"
#import "SOCSentryFrame.h"
#import "SOCSentryGeo.h"
#import "SOCSentryId.h"
#import "SOCSentryMechanismContext.h"
#import "SOCSentryMessage.h"
#import "SOCSentryRequest.h"
#import "SOCSentrySpanId.h"
#import "SOCSentryTraceContext.h"

// Mid-level classes (depend on leaves)
#import "SOCSentryAttachment.h"
#import "SOCSentryBreadcrumb.h"
#import "SOCSentryMechanism.h"
#import "SOCSentryStacktrace.h"
#import "SOCSentryThread.h"
#import "SOCSentryTraceHeader.h"
#import "SOCSentryUser.h"
#import "SOCSentrySpanContext.h"
#import "SOCSentryTransactionContext.h"
#import "SOCSentrySamplingContext.h"

// Composites
#import "SOCSentryException.h"
#import "SOCSentryFeedback.h"
#import "SOCSentryFeedbackAPI.h"
#import "SOCSentrySpan.h"
#import "SOCSentryEvent.h"
#import "SOCSentryScope.h"
#import "SOCSentryOptions.h"
#import "SOCSentryClient.h"
#import "SOCSentryHub.h"

// SDK entry point
#import "SOCSentrySDK.h"
