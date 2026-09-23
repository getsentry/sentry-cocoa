#import "SentryClient+ErrorEvents.h"
#import "SentryEvent+Private.h"
#import "SentryException.h"
#import "SentryLogC.h"
#import "SentryMechanism.h"
#import "SentryMechanismContext.h"
#import "SentryNSError.h"
#import "SentrySanitizerUtils.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryClientInternal (ErrorEvents)

- (SentryEvent *)buildExceptionEvent:(NSException *)exception
{
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelError];
    SentryException *sentryException = [[SentryException alloc] initWithValue:exception.reason
                                                                         type:exception.name];

    event.exceptions = @[ sentryException ];

    [self setUserInfo:exception.userInfo withEvent:event];
    return event;
}

- (SentryEvent *)buildErrorEvent:(NSError *)error
{
    SentryEvent *event = [[SentryEvent alloc] initWithError:error];

    // flatten any recursive description of underlying errors into a list, to ultimately report them
    // as a list of exceptions with error mechanisms, sorted oldest to newest (so, the leaf node
    // underlying error as oldest, with the root as the newest)
    NSMutableArray<NSError *> *errors = [NSMutableArray<NSError *> arrayWithObject:error];
    NSError *underlyingError;
    if ([error.userInfo[NSUnderlyingErrorKey] isKindOfClass:[NSError class]]) {
        underlyingError = error.userInfo[NSUnderlyingErrorKey];
    } else if (error.userInfo[NSUnderlyingErrorKey] != nil) {
        SENTRY_LOG_WARN(@"Invalid value for NSUnderlyingErrorKey in user info. Data at key: %@. "
                        @"Class type: %@.",
            error.userInfo[NSUnderlyingErrorKey], [error.userInfo[NSUnderlyingErrorKey] class]);
    }

    while (underlyingError != nil) {
        [errors addObject:underlyingError];

        if ([underlyingError.userInfo[NSUnderlyingErrorKey] isKindOfClass:[NSError class]]) {
            underlyingError = underlyingError.userInfo[NSUnderlyingErrorKey];
        } else {
            if (underlyingError.userInfo[NSUnderlyingErrorKey] != nil) {
                SENTRY_LOG_WARN(@"Invalid value for NSUnderlyingErrorKey in user info. Data at "
                                @"key: %@. Class type: %@.",
                    underlyingError.userInfo[NSUnderlyingErrorKey],
                    [underlyingError.userInfo[NSUnderlyingErrorKey] class]);
            }
            underlyingError = nil;
        }
    }

    NSMutableArray<SentryException *> *exceptions = [NSMutableArray<SentryException *> array];
    [errors enumerateObjectsWithOptions:NSEnumerationReverse
                             usingBlock:^(NSError *_Nonnull nextError, NSUInteger __unused idx,
                                 BOOL *_Nonnull __unused stop) {
                                 [exceptions addObject:[self exceptionForError:nextError]];
                             }];

    event.exceptions = exceptions;

    // Once the UI displays the mechanism data we can remove the userInfo from the event.context
    // using only the root error's userInfo.
    [self setUserInfo:sentry_sanitize_dictionary(error.userInfo) withEvent:event];

    return event;
}

- (SentryException *)exceptionForError:(NSError *)error
{
    NSString *exceptionValue;

    // If the error has a debug description, use that.
    NSString *customExceptionValue = [[error userInfo] valueForKey:NSDebugDescriptionErrorKey];

    NSString *swiftErrorDescription = nil;
    // SwiftNativeNSError is the subclass of NSError used to represent bridged native Swift errors,
    // see
    // https://github.com/apple/swift/blob/067e4ec50147728f2cb990dbc7617d66692c1554/stdlib/public/runtime/ErrorObject.mm#L63-L73
    NSString *errorClass = NSStringFromClass(error.class);
    if ([errorClass containsString:@"SwiftNativeNSError"]) {
        swiftErrorDescription = [SwiftDescriptor getSwiftErrorDescription:error];
    }

    if (customExceptionValue != nil) {
        exceptionValue =
            [NSString stringWithFormat:@"%@ (Code: %ld)", customExceptionValue, (long)error.code];
    } else if (swiftErrorDescription != nil) {
        exceptionValue =
            [NSString stringWithFormat:@"%@ (Code: %ld)", swiftErrorDescription, (long)error.code];
    } else {
        exceptionValue = [NSString stringWithFormat:@"Code: %ld", (long)error.code];
    }
    SentryException *exception = [[SentryException alloc] initWithValue:exceptionValue
                                                                   type:error.domain];

    // Sentry uses the error domain and code on the mechanism for grouping
    SentryMechanism *mechanism = [[SentryMechanism alloc] initWithType:@"NSError"];
    SentryMechanismContext *mechanismMeta = [[SentryMechanismContext alloc] init];
    mechanismMeta.error = [[SentryNSError alloc] initWithDomain:error.domain code:error.code];
    mechanism.meta = mechanismMeta;
    // The description of the error can be especially useful for error from swift that
    // use a simple enum.
    mechanism.desc = error.description;

    NSDictionary<NSString *, id> *userInfo = sentry_sanitize_dictionary(error.userInfo);
    mechanism.data = userInfo;
    exception.mechanism = mechanism;

    return exception;
}

@end

NS_ASSUME_NONNULL_END
