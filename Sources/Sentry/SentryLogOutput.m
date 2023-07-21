#import "SentryLogOutput.h"

#if __has_include(<os/log.h>)
#import <os/log.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation SentryLogOutput {
    id _os_log;
}

- (instancetype)init {
    if (self = [super init]) {
        if (@available(iOS 10.0, macOS 10.12, macCatalyst 13.1, tvOS 10.0, watchOS 3.0, *)) {
            _os_log = os_log_create("io.sentry.log", "any");
        }
    }
    return self;
}

- (void)log:(NSString *)message {
    if (_os_log && @available(iOS 10.0, macOS 10.12, macCatalyst 13.1, tvOS 10.0, watchOS 3.0, *)) {
        os_log_debug(_os_log, "%{public}s", [message UTF8String]);
    } else {
        NSLog(@"%@", message);
    }
}

@end

NS_ASSUME_NONNULL_END
