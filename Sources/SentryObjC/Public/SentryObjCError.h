#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SentryObjCErrorCode) {
    SentryObjCErrorCodeUnknownError = -1,
    SentryObjCErrorCodeInvalidDsnError = 100,
    SentryObjCErrorCodeSentryCrashNotInstalledError = 101,
    SentryObjCErrorCodeInvalidCrashReportError = 102,
    SentryObjCErrorCodeCompressionError = 103,
    SentryObjCErrorCodeJsonConversionError = 104,
    SentryObjCErrorCodeCouldNotFindDirectory = 105,
    SentryObjCErrorCodeRequestError = 106,
    SentryObjCErrorCodeEventNotSent = 107,
    SentryObjCErrorCodeFileIO = 108,
    SentryObjCErrorCodeKernel = 109,
};

/**
 * Creates @c NSError instances for SDK error codes.
 */
@interface SentryObjCError : NSObject
SENTRY_NO_INIT

/**
 * Creates an @c NSError with the SDK error domain.
 * @param code The SDK error code.
 * @param description The localized error description.
 */
+ (NSError *)nsErrorWithCode:(SentryObjCErrorCode)code description:(NSString *)description;

@end

NS_ASSUME_NONNULL_END
