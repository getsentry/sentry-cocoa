// Sentry internal headers that are needed for swift code
#import "SentryBaggage.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryNSDataUtils.h"
#import "SentryRandom.h"
#import "SentryReplayRecording.h"
#import "SentryReplayType.h"
#import "SentrySdkInfo.h"
#import "SentryStatsdClient.h"
#import "SentryTime.h"

// Headers that also import SentryDefines should be at the end of this list
// otherwise it wont compile
