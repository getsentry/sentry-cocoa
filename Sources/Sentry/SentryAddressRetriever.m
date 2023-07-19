#import "SentryAddressRetriever.h"
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
    Dl_info symbolsBuffer;

    bool symbols_succeed = false;

    symbols_succeed
        = dladdr((void *)sentry_convertHexAddressToUInt64(instructionAddress), &symbolsBuffer) != 0;
    uintptr_t symbolAddress = (uintptr_t)symbolsBuffer.dli_saddr;

    return sentry_formatHexAddressUInt64(symbolAddress);
}

NSString *_Nullable sentry_retrieveAddressForClass(Class clazz, SEL aSelector)
{
    if (![clazz respondsToSelector:aSelector]) {
        return nil;
    }

    IMP pointer = [clazz instanceMethodForSelector:aSelector];
    return sentry_formatHexAddressUInt64((uintptr_t)pointer);
}
