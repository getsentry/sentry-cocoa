#import "SentryScope+Equality.h"
#import "SentryScope+Properties.h"
#import "SentryUser.h"

@implementation
SentryScope (Equality)

- (BOOL)isEqual:(id _Nullable)other
{
    if (other == self)
        return YES;
    if (!other || ![[other class] isEqual:[self class]])
        return NO;

    return [self isEqualToScope:other];
}

- (BOOL)isEqualToScope:(SentryScope *)scope
{
    if (self == scope)
        return YES;
    if (scope == nil)
        return NO;
    if (self.userObject != scope.userObject && ![self.userObject isEqualToUser:scope.userObject])
        return NO;
    if (self.tagDictionary != scope.tagDictionary
        && ![self.tagDictionary isEqualToDictionary:scope.tagDictionary])
        return NO;
    if (self.extraDictionary != scope.extraDictionary
        && ![self.extraDictionary isEqualToDictionary:scope.extraDictionary])
        return NO;
    if (self.contextDictionary != scope.contextDictionary
        && ![self.contextDictionary isEqualToDictionary:scope.contextDictionary])
        return NO;
    if (self.breadcrumbArray != scope.breadcrumbArray
        && ![self.breadcrumbArray isEqualToArray:scope.breadcrumbArray])
        return NO;
    if (self.distString != scope.distString && ![self.distString isEqualToString:scope.distString])
        return NO;
    if (self.environmentString != scope.environmentString
        && ![self.environmentString isEqualToString:scope.environmentString])
        return NO;
    if (self.fingerprintArray != scope.fingerprintArray
        && ![self.fingerprintArray isEqualToArray:scope.fingerprintArray])
        return NO;
    if (self.levelEnum != scope.levelEnum)
        return NO;
    if (self.maxBreadcrumbs != scope.maxBreadcrumbs)
        return NO;
    if (self.attachmentArray != scope.attachmentArray
        && ![self.attachmentArray isEqualToArray:scope.attachmentArray])
        return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = [self.userObject hash];
    hash = hash * 23 + [self.tagDictionary hash];
    hash = hash * 23 + [self.extraDictionary hash];
    hash = hash * 23 + [self.contextDictionary hash];
    hash = hash * 23 + [self.breadcrumbArray hash];
    hash = hash * 23 + [self.distString hash];
    hash = hash * 23 + [self.environmentString hash];
    hash = hash * 23 + [self.fingerprintArray hash];
    hash = hash * 23 + (NSUInteger)self.levelEnum;
    hash = hash * 23 + self.maxBreadcrumbs;
    hash = hash * 23 + [self.attachmentArray hash];
    return hash;
}

@end
