#import <Foundation/Foundation.h>
#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentryDefines.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <SentryWithoutUIKit/SentryDefines.h>
#else
#    import <SentryDefines.h>
#endif
#if !SDK_V9
#    import SENTRY_HEADER(SentrySerializable)
#endif

NS_ASSUME_NONNULL_BEGIN

@class SentryNSError;
@class SentryMechanismMeta;

NS_SWIFT_NAME(Mechanism)
@interface SentryMechanism : NSObject
#if !SDK_V9
                             <SentrySerializable>
#endif

SENTRY_NO_INIT

/**
 * A unique identifier of this mechanism determining rendering and processing
 * of the mechanism data
 */
@property (nonatomic, copy) NSString *type;

/**
 * Human readable description of the error mechanism and a possible hint on how to solve this error.
 * We can't use description as it overlaps with NSObject.description.
 */
@property (nonatomic, copy) NSString *_Nullable desc;

/**
 * Arbitrary extra data that might help the user understand the error thrown by
 * this mechanism
 */
@property (nonatomic, strong) NSDictionary<NSString *, id> *_Nullable data;

/**
 * Flag indicating whether the exception has been handled by the user
 * (e.g. via @c try..catch )
 */
@property (nonatomic, copy) NSNumber *_Nullable handled;

/**
 * An optional flag indicating a synthetic exception. For more info visit
 * https://develop.sentry.dev/sdk/event-payloads/exception/#exception-mechanism.
 */
@property (nonatomic, copy, nullable) NSNumber *synthetic;

/**
 * Fully qualified URL to an online help resource, possible
 * interpolated with error parameters
 */
@property (nonatomic, copy) NSString *_Nullable helpLink;

/**
 * Information from the operating system or runtime on the exception
 * mechanism.
 */
@property (nullable, nonatomic, strong) SentryMechanismMeta *meta;

/**
 * Initialize an SentryMechanism with a type
 * @param type String
 * @return SentryMechanism
 */
- (instancetype)initWithType:(NSString *)type;

@end

NS_ASSUME_NONNULL_END
