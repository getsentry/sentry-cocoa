// Sentry internal headers that are needed for swift code; you cannot import headers that depend on
// public interfaces here
#import "NSLocale+Sentry.h"
#import "SentryByteCountFormatter.h"
#import "SentryClient+Private.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryNSDataUtils.h"
#import "SentryRandom.h"
#import "SentrySDK+Private.h"
#import "SentryTime.h"
#import "SentryTraceOrigins.h"
#import "SentryUserAccess.h"

// Headers that also import SentryDefines should be at the end of this list
// otherwise it wont compile
#import "SentryDateUtil.h"
#import "SentryDisplayLinkWrapper.h"
#import "SentryLevelHelper.h"
#import "SentryLogC.h"
#import "SentryRandom.h"
#import "SentrySdkInfo.h"
#import "SentrySession.h"
