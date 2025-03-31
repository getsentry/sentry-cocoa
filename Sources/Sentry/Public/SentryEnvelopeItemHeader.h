#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentrySerializable.h>
#else
#    import <SentryWithoutUIKit/SentrySerializable.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryEnvelopeItemHeader : NSObject <SentrySerializable>
SENTRY_NO_INIT

- (instancetype)initWithType:(NSString *)type length:(NSUInteger)length NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithType:(NSString *)type
                      length:(NSUInteger)length
                 contentType:(NSString *)contentType;

- (instancetype)initWithType:(NSString *)type
                      length:(NSUInteger)length
                   filenname:(NSString *)filename
                 contentType:(NSString *)contentType;

/**
 * The type of the envelope item.
 */
@property (nonatomic, readonly, copy) NSString *type;
@property (nonatomic, readonly) NSUInteger length;
@property (nonatomic, readonly, copy, nullable) NSString *filename;
@property (nonatomic, readonly, copy, nullable) NSString *contentType;

/**
 * Some envelopes need to report the platform name for enhanced rate limiting functionality in
 * relay.
 */
@property (nonatomic, copy, nullable) NSString *platform;

@end

NS_ASSUME_NONNULL_END
