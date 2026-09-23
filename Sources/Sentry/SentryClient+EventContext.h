#import "SentryClient+Private.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryClientInternal ()

@property (nonatomic, strong) NSLocale *locale;
@property (nonatomic, strong) NSTimeZone *timezone;

@end

@interface SentryClientInternal (EventContext)

- (void)setSdk:(SentryEvent *)event;
- (void)setUserIdIfNoUserSet:(SentryEvent *)event;
- (BOOL)isWatchdogTermination:(SentryEvent *)event isFatalEvent:(BOOL)isFatalEvent;
- (void)applyCultureContextToEvent:(SentryEvent *)event;
- (void)applyExtraDeviceContextToEvent:(SentryEvent *)event;
#if SENTRY_HAS_UIKIT
- (void)applyCurrentViewNamesToEventContext:(SentryEvent *)event withScope:(SentryScope *)scope;
#endif // SENTRY_HAS_UIKIT
- (void)removeExtraDeviceContextFromEvent:(SentryEvent *)event;

@end

NS_ASSUME_NONNULL_END
