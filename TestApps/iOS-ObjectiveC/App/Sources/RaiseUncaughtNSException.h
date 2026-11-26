#import <Foundation/Foundation.h>

/// Raises an uncaught NSException using the same ObjC @throw path as CrashE2E.
/// Call this instead of raising from an IBAction body; UIKit/LLDB otherwise
/// turn the failure into a mach abort.
void RaiseUncaughtNSException(NSString *name, NSString *reason);
