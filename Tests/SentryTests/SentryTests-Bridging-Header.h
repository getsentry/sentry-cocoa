// These declarations still depend on Swift-owned types across the Objective-C/Swift
// boundary. Import ordinary SDK and test declarations from their owning modules instead.
#import "SentryDefines.h"
#import "SentryLaunchProfiling+Tests.h"

// Load the Objective-C base declarations before their generated Swift interface.
@import _SentryPrivate;
#import "SentryClient+TestInit.h"
#import "SentryCrashStackEntryMapper.h"
#import "SentryEnvelopeRateLimit.h"
#import "SentryHttpTransport.h"
#import "SentryHub+Test.h"
#import "SentrySDKInternal+Tests.h"
#import "SentrySwift.h"
#import "SentryTransportFactory.h"
