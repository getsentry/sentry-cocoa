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
#import "SentryByteCountFormatter.h"
#import "SentryClient+Private.h"
#import "SentryDateUtil.h"
#import "SentryDisplayLinkWrapper.h"
#import "SentryFileIOTracker.h"
#import "SentryFileManager.h"
#import "SentryLevelHelper.h"
#import "SentryLogC.h"
#import "SentryRandom.h"
#import "SentrySDK+Private.h"
#import "SentrySdkInfo.h"
#import "SentrySession.h"
#import "SentrySpanOperations.h"
#import "SentryTraceOrigins.h"
