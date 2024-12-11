// Sentry internal headers that are needed for swift code
#import "NSLocale+Sentry.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryNSDataUtils.h"
#import "SentryRandom.h"
#import "SentryTime.h"

// Headers that also import SentryDefines should be at the end of this list
// otherwise it wont compile
#import "SentryDateUtil.h"
#import "SentryDisplayLinkWrapper.h"
#import "SentryLevelHelper.h"
#import "SentryLogC.h"
#import "SentryRandom.h"
#import "SentrySession.h"
