// Umbrella header for the `SentryObjC` SPM target. Importing this single
// header brings in every public class and enum mirroring the Swift
// `SentryObjCCompat` module. Non-modular ObjC consumers can either #import
// this umbrella or pick out individual headers as needed.

// Enums
#import "SentryCompatAttachmentType.h"
#import "SentryCompatFeedbackSource.h"
#import "SentryCompatLastRunStatus.h"
#import "SentryCompatLevel.h"
#import "SentryCompatSampleDecision.h"
#import "SentryCompatSpanStatus.h"
#import "SentryCompatTransactionNameSource.h"

// Leaf classes
#import "SentryCompatDebugMeta.h"
#import "SentryCompatDsn.h"
#import "SentryCompatFrame.h"
#import "SentryCompatGeo.h"
#import "SentryCompatId.h"
#import "SentryCompatMechanismContext.h"
#import "SentryCompatMessage.h"
#import "SentryCompatRequest.h"
#import "SentryCompatSpanId.h"
#import "SentryCompatTraceContext.h"

// Mid-level classes (depend on leaves)
#import "SentryCompatAttachment.h"
#import "SentryCompatBreadcrumb.h"
#import "SentryCompatMechanism.h"
#import "SentryCompatStacktrace.h"
#import "SentryCompatThread.h"
#import "SentryCompatTraceHeader.h"
#import "SentryCompatUser.h"
#import "SentryCompatSpanContext.h"
#import "SentryCompatTransactionContext.h"
#import "SentryCompatSamplingContext.h"

// Composites
#import "SentryCompatException.h"
#import "SentryCompatFeedback.h"
#import "SentryCompatFeedbackAPI.h"
#import "SentryCompatSpan.h"
#import "SentryCompatEvent.h"
#import "SentryCompatScope.h"
#import "SentryCompatOptions.h"
#import "SentryCompatClient.h"
#import "SentryCompatHub.h"

// SDK entry point
#import "SentryCompat.h"
