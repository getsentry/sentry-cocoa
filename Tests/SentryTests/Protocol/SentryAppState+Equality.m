#import "SentryAppState+Equality.h"

NS_ASSUME_NONNULL_BEGIN

@implementation
SentryAppState (Equality)

- (BOOL)isEqual:(id _Nullable)other
{
    if (other == self)
        return YES;
    if (!other || ![[other class] isEqual:[self class]])
        return NO;

    return [self isEqualToAppState:other];
}

- (BOOL)isEqualToAppState:(SentryAppState *_Nullable)appState
{
    if (self == appState)
        return YES;
    if (appState == nil)
        return NO;
    if (self.releaseName != appState.releaseName
        && ![self.releaseName isEqualToString:appState.releaseName])
        return NO;
    if (self.osVersion != appState.osVersion
        && ![self.osVersion isEqualToString:appState.osVersion])
        return NO;
    if (self.isDebugging != appState.isDebugging)
        return NO;
    if (self.systemBootTimestamp != appState.systemBootTimestamp
        && ![self.systemBootTimestamp isEqualToDate:appState.systemBootTimestamp])
        return NO;
    if (self.isActive != appState.isActive)
        return NO;
    if (self.wasTerminated != appState.wasTerminated)
        return NO;

    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = 17;

    hash = hash * 23 + [self.releaseName hash];
    hash = hash * 23 + [self.osVersion hash];
    hash = hash * 23 + [@(self.isDebugging) hash];
    hash = hash * 23 + [self.systemBootTimestamp hash];
    hash = hash * 23 + [@(self.isActive) hash];
    hash = hash * 23 + [@(self.wasTerminated) hash];

    return hash;
}

@end

NS_ASSUME_NONNULL_END
