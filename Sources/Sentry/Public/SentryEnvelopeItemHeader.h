#import "SentryDefines.h"
#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryEnvelopeItemHeader : SENTRY_BASE_OBJECT <SentrySerializable>
SENTRY_NO_INIT

- (instancetype)initWithType:(NSString *)type length:(NSUInteger)length NS_DESIGNATED_INITIALIZER;

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

@end

NS_ASSUME_NONNULL_END
