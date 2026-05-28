#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

@class SentryObjCMechanismContext;

NS_ASSUME_NONNULL_BEGIN

/**
 * The mechanism by which an exception was generated and handled.
 */
@interface SentryObjCMechanism : NSObject
SENTRY_NO_INIT

/**
 * A unique identifier of this mechanism determining rendering and processing
 * of the mechanism data.
 */
@property (nonatomic, copy) NSString *type;

/**
 * Human readable description of the error mechanism and a possible hint on how to solve this error.
 */
@property (nonatomic, copy, nullable) NSString *desc;

/**
 * Arbitrary extra data that might help the user understand the error thrown by
 * this mechanism.
 */
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *data;

/**
 * Flag indicating whether the exception has been handled by the user
 * (e.g. via @c try..catch ).
 */
@property (nonatomic, copy, nullable) NSNumber *handled;

/**
 * An optional flag indicating a synthetic exception. For more info visit
 * https://develop.sentry.dev/sdk/event-payloads/exception/#exception-mechanism.
 */
@property (nonatomic, copy, nullable) NSNumber *synthetic;

/**
 * Fully qualified URL to an online help resource, possibly
 * interpolated with error parameters.
 */
@property (nonatomic, copy, nullable) NSString *helpLink;

/**
 * Information from the operating system or runtime on the exception
 * mechanism.
 */
@property (nonatomic, strong, nullable) SentryObjCMechanismContext *meta;

/**
 * Initialize a @c SentryObjCMechanism with a type.
 * @param type The unique identifier of the mechanism.
 */
- (instancetype)initWithType:(NSString *)type;

@end

NS_ASSUME_NONNULL_END
