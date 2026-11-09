#import "SentryDefines.h"

// Scope lives in SentrySwift. This Clang module cannot name it: @import SentrySwift from a
// modular header fails SwiftPM dependency scanning with "module 'SentrySwift' not found".
// Tests call propagationContext and applyTo(session:) on Scope directly.
