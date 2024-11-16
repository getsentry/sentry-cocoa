// Sentry internal headers that are needed for swift code
#import "NSLocale+Sentry.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryNSDataUtils.h"
#import "SentryRandom.h"
#import "SentrySDK+Private.h"
#import "SentryScope+Private.h"
#import "SentryTime.h"
#import "SentrySDK+Private.h"

// Headers that also import SentryDefines should be at the end of this list
// otherwise it wont compile
#import "SentryDateUtil.h"
#import "SentryDisplayLinkWrapper.h"
#import "SentryLevelHelper.h"
#import "SentryLogC.h"
#import "SentryRandom.h"
#import "SentrySdkInfo.h"
#import "SentrySession.h"
