#import "SentryDescriptor.h"
#import "SentryDemangler.h"

static SentryDescriptor * _globalDescriptor;


NSString * objectClassName(NSObject *object) {
    return [_globalDescriptor getClassDescription:object];
}

@implementation SentryDescriptor {
    SentryDemangler * demangler;
}

+(void)initialize
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

- (NSString *)getClassDescription:(NSObject *)object {
    NSString * result = NSStringFromClass(object.class);
    if ([demangler isMangled:result])
        result = [demangler demangleClassName:result];
    return result;
}

@end
