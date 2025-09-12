#import "SentryDsn.h"

#if SDK_V9
@interface SentryDsn (Private)

- (NSString *)getHash;

@end
#endif // SDK_V9
