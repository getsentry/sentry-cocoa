#import "SentryCompiler.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN_C_BEGIN

NSString *getSymbolAddressForInstructionAddress(NSString *instructionAddress);

NSString *_Nullable sentry_retrieveAddressForObject(NSObject *instance, SEL aSelector);

NSString *_Nullable sentry_retrieveAddressForClass(Class clazz, SEL aSelector);

SENTRY_EXTERN_C_END

NS_ASSUME_NONNULL_END
