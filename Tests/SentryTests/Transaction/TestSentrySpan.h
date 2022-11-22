#import "SentrySpanProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface TestSentrySpan : NSObject <SentrySpan>

- (void)setExtraValue:(nullable id)value forKey:(nonnull NSString *)key DEPRECATED_ATTRIBUTE;

@end

NS_ASSUME_NONNULL_END
