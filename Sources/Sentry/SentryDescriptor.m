#import "SentryDescriptor.h"
#import "SentryDemangler.h"

static SentryDescriptor *_globalDescriptor;

NSString *
sentry_getClassDescription(Class aClass)
{
    return [_globalDescriptor getClassDescription:aClass];
}

NSString *
sentry_getObjectClassDescription(NSObject *object)
{
    return [_globalDescriptor getObjectClassDescription:object];
}

NSString *
sentry_getDescription(NSObject *object)
{
    return [_globalDescriptor getDescription:object];
}

void
sentry_setGlobalDescriptor(SentryDescriptor *descriptor)
{
    _globalDescriptor = descriptor ?: [[SentryDescriptor alloc] init];
}

@implementation SentryDescriptor {
    SentryDemangler *demangler;
}

+ (void)load
{
    _globalDescriptor = [[SentryDescriptor alloc] init];
}

- (instancetype)init
{
    if (self = [super init]) {
        demangler = [[SentryDemangler alloc] init];
    }
    return self;
}

- (NSString *)getClassDescription:(Class)aClass
{
    NSString *result = NSStringFromClass(aClass);
    if ([demangler isMangled:result])
        result = [demangler demangleClassName:result];
    return result;
}

- (NSString *)getObjectClassDescription:(NSObject *)object
{
    return [self getClassDescription:object.class];
}

- (NSString *)getDescription:(NSObject *)object
{
    NSString *result = object.description;
    if ([demangler isMangled:result])
        result = [demangler demangleClassName:result];
    return result;
}

@end
