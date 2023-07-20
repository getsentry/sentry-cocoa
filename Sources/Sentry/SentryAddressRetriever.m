#import "SentryAddressRetriever.h"
#import "SentryCrashSymbolicator.h"
#import <Foundation/Foundation.h>
#import <SentryFormatter.h>
#import <dlfcn.h>
#import <objc/runtime.h>

NSString *_Nullable sentry_retrieveAddressForObject(NSObject *instance, SEL aSelector)
{
    if (![instance respondsToSelector:aSelector]) {
        return nil;
    }

    IMP pointer = [instance methodForSelector:aSelector];
    uintptr_t address = (uintptr_t)pointer;

    return sentry_formatHexAddressUInt64(address);
}

uint64_t
sentry_convertHexAddressToUInt64(NSString *hexAddress)
{
    NSScanner *scanner = [NSScanner scannerWithString:hexAddress];
    [scanner scanString:@"0x" intoString:nil];

    uint64_t value = 0;
    [scanner scanHexLongLong:&value];

    return value;
}

NSString *
getSymbolAddressForInstructionAddress(NSString *instructionAddress)
{
    SentryCrashStackEntry stackEntry;
    stackEntry.address = sentry_convertHexAddressToUInt64(instructionAddress);

    sentrycrashsymbolicator_symbolicate_stack_entry(&stackEntry, false);

    return sentry_formatHexAddressUInt64(stackEntry.symbolAddress);
}

NSString *_Nullable sentry_retrieveAddressForClass(Class clazz, SEL aSelector)
{
    if (![clazz respondsToSelector:aSelector]) {
        return nil;
    }

    IMP pointer = [clazz instanceMethodForSelector:aSelector];
    return sentry_formatHexAddressUInt64((uintptr_t)pointer);
}
