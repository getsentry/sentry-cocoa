#import "SentrySession+Equality.h"
#import "SentryUser.h"

@implementation
SentrySession (Equality)

- (BOOL)isEqual:(id _Nullable)other
{
    if (other == self)
        return YES;
    if (!other || ![[other class] isEqual:[self class]])
        return NO;

    return [self isEqualToSession:other];
}

- (BOOL)isEqualToSession:(SentrySession *)session
{
    if (self == session)
        return YES;
    if (session == nil)
        return NO;
    if (self.sessionId != session.sessionId && ![self.sessionId isEqual:session.sessionId])
        return NO;
    if (self.started != session.started && ![self.started isEqualToDate:session.started])
        return NO;
    if (self.status != session.status)
        return NO;
    if (self.hasErrors != session.hasErrors)
        return NO;
    if (self.sequence != session.sequence)
        return NO;
    if (self.distinctId != session.distinctId
        && ![self.distinctId isEqualToString:session.distinctId])
        return NO;
    if (self.timestamp != session.timestamp && ![self.timestamp isEqualToDate:session.timestamp])
        return NO;
    if (self.duration != session.duration && ![self.duration isEqualToNumber:session.duration])
        return NO;
    if (self.releaseName != session.releaseName
        && ![self.releaseName isEqualToString:session.releaseName])
        return NO;
    if (self.environment != session.environment
        && ![self.environment isEqualToString:session.environment])
        return NO;
    if (self.user != session.user && ![self.user isEqual:session.user])
        return NO;
    if (self.flagInit != session.flagInit && ![self.flagInit isEqualToNumber:session.flagInit])
        return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = 17;

    hash = hash * 23 + [self.sessionId hash];
    hash = hash * 23 + [self.started hash];
    hash = hash * 23 + self.status;
    hash = hash * 23 + self.hasErrors;
    hash = hash * 23 + self.sequence;
    hash = hash * 23 + [self.distinctId hash];
    hash = hash * 23 + [self.flagInit hash];
    hash = hash * 23 + [self.timestamp hash];
    hash = hash * 23 + [self.releaseName hash];
    hash = hash * 23 + [self.environment hash];
    hash = hash * 23 + [self.user hash];

    return hash;
}

@end
