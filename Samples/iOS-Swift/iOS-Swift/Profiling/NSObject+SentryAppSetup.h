#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A category that overrides its `+[load]` method to deliberately take a long time to run, so we can
 * see it show up in profile stack traces. Categories' `+[load]` methods are guaranteed to be called
 * after all of a module's normal class' overrides, so we can be confident the ordering will always
 * have started the launch profiler by the time this runs. This must be done in Objective-C because
 * Swift does not allow implementation of `NSObject.load()`.
 */
@interface
NSObject (SentryAppSetup)
@end

NS_ASSUME_NONNULL_END
