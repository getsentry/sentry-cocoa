#import "SentryClient+EventContext.h"
#import "SentryDeviceContextKeys.h"
#import "SentryEvent+Private.h"
#import "SentryException.h"
#import "SentryInternalDefines.h"
#import "SentryMechanism.h"
#import "SentryScope+Private.h"
#import "SentrySwift.h"
#import "SentryTransaction+Private.h"
#import "SentryUser.h"

__attribute__((visibility("hidden"))) void
sentry_client_event_context_linker_anchor(void)
{
}

NS_ASSUME_NONNULL_BEGIN

@implementation SentryClientInternal (EventContext)

- (void)setSdk:(SentryEvent *)event
{
    if (event.sdk) {
        return;
    }

    event.sdk = [SentrySdkInfoObjC optionsToDict:self.options];
}

- (void)setUserIdIfNoUserSet:(SentryEvent *)event
{
#if SDK_V10
    if (!self.options.dataCollectionObjC.userInfo) {
        return;
    }
#endif // SDK_V10
    // We only want to set the id if the customer didn't set a user so we at least set something to
    // identify the user.
    if (event.user == nil) {
        SentryUser *user = [[SentryUser alloc] init];
        user.userId = [SentryInstallation idWithCacheDirectoryPath:self.options.cacheDirectoryPath];
        event.user = user;
    }
}

- (BOOL)isWatchdogTermination:(SentryEvent *)event isFatalEvent:(BOOL)isFatalEvent
{
    if (!isFatalEvent) {
        return NO;
    }

    if (event.exceptions == nil || event.exceptions.count != 1) {
        return NO;
    }

    SentryException *exception = event.exceptions[0];
    return exception.mechanism != nil &&
        [exception.mechanism.type isEqualToString:SentryWatchdogTerminationConstants.MechanismType];
}

- (void)applyCultureContextToEvent:(SentryEvent *)event
{
    [self modifyContext:event
                    key:@"culture"
                  block:^(NSMutableDictionary *culture) {
                      culture[@"calendar"] = [self.locale
                          localizedStringForCalendarIdentifier:self.locale.calendarIdentifier];
                      culture[@"display_name"] = [self.locale
                          localizedStringForLocaleIdentifier:self.locale.localeIdentifier];
                      culture[@"locale"] = self.locale.localeIdentifier;
                      culture[@"is_24_hour_format"] = @([SentryLocale timeIs24HourFormat]);
                      culture[@"timezone"] = self.timezone.name;
                  }];
}

- (void)applyExtraDeviceContextToEvent:(SentryEvent *)event
{
    NSDictionary *extraContext =
        [SentryDependencyContainer.sharedInstance.extraContextProvider getExtraContext];
    [self modifyContext:event
                    key:SENTRY_CONTEXT_DEVICE_KEY
                  block:^(NSMutableDictionary *device) {
                      if (extraContext[SENTRY_CONTEXT_DEVICE_KEY] != nil &&
                          [extraContext[SENTRY_CONTEXT_DEVICE_KEY]
                              isKindOfClass:NSDictionary.class]) {
                          [device addEntriesFromDictionary:extraContext[SENTRY_CONTEXT_DEVICE_KEY]
                                  ?: @ { }];
                      }
                  }];

    [self modifyContext:event
                    key:SENTRY_CONTEXT_APP_KEY
                  block:^(NSMutableDictionary *app) {
                      if (extraContext[SENTRY_CONTEXT_APP_KEY] != nil &&
                          [extraContext[SENTRY_CONTEXT_APP_KEY] isKindOfClass:NSDictionary.class]) {
                          [app addEntriesFromDictionary:extraContext[SENTRY_CONTEXT_APP_KEY]
                                  ?: @ { }];
                      }
                  }];
}

#if SENTRY_HAS_UIKIT
- (void)applyCurrentViewNamesToEventContext:(SentryEvent *)event withScope:(SentryScope *)scope
{
    [self modifyContext:event
                    key:@"app"
                  block:^(NSMutableDictionary *app) {
                      if ([event isKindOfClass:[SentryTransaction class]]) {
                          SentryTransaction *transaction = (SentryTransaction *)event;
                          if ([transaction.viewNames count] > 0) {
                              app[@"view_names"] = transaction.viewNames;
                          }
                      } else {
                          if (scope.currentScreen != nil) {
                              app[@"view_names"] =
                                  @[ SENTRY_UNWRAP_NULLABLE(NSString, scope.currentScreen) ];
                          } else {
                              app[@"view_names"] = [SentryDependencyContainer.sharedInstance
                                      .application relevantViewControllersNames];
                          }
                      }
                  }];
}
#endif // SENTRY_HAS_UIKIT

- (void)removeExtraDeviceContextFromEvent:(SentryEvent *)event
{
    [self modifyContext:event
                    key:SENTRY_CONTEXT_DEVICE_KEY
                  block:^(NSMutableDictionary *device) {
                      [device removeObjectForKey:SentryDeviceContextFreeMemoryKey];
                      [device removeObjectForKey:@"orientation"];
                      [device removeObjectForKey:@"charging"];
                      [device removeObjectForKey:@"battery_level"];
                      [device removeObjectForKey:@"thermal_state"];
                  }];

    [self modifyContext:event
                    key:@"app"
                  block:^(NSMutableDictionary *app) {
                      [app removeObjectForKey:SentryDeviceContextAppMemoryKey];
                  }];
}

- (void)modifyContext:(SentryEvent *)event
                  key:(NSString *)key
                block:(void (^)(NSMutableDictionary *))block
{
    if (event.context == nil || event.context.count == 0) {
        return;
    }

    NSMutableDictionary *context = [[NSMutableDictionary alloc]
        initWithDictionary:SENTRY_UNWRAP_NULLABLE(NSDictionary, event.context)];
    NSMutableDictionary *dict
        = event.context[key] != nil && [event.context[key] isKindOfClass:[NSDictionary class]]
        ? [[NSMutableDictionary alloc]
              initWithDictionary:SENTRY_UNWRAP_NULLABLE(NSDictionary, context[key])]
        : [NSMutableDictionary dictionary];

    block(dict);
    context[key] = dict;
    event.context = context;
}

@end

NS_ASSUME_NONNULL_END
