// Sentry internal headers that are needed for swift code; you cannot import headers that depend on
// public interfaces here
#import "NSLocale+Sentry.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryNSDataUtils.h"
#import "SentryRandom.h"
#import "SentryTime.h"
#import "SentryUserAccess.h"

// Headers that also import SentryDefines should be at the end of this list
// otherwise it wont compile
#import "SentryDateUtil.h"
#import "SentryDateUtils.h"
#import "SentryDisplayLinkWrapper.h"
#import "SentryFileIOTracker.h"
#import "SentryLevelHelper.h"
#import "SentryLogC.h"
#import "SentryMeta.h"
#import "SentryProfiler+Private.h"
#import "SentryRandom.h"
#import "SentryScreenshot.h"
#import "SentrySdkInfo.h"
#import "SentrySession.h"
#import "SentrySpanDataKey.h"
#import "SentrySpanOperation.h"
#import "SentryTraceHeader.h"
#import "SentryTraceOrigin.h"
