#import "SentryDefines.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryQueueableRequestManager : NSObject <SentryRequestManager>

- (instancetype)initWithSession:(NSURLSession *)session;

@end

NS_ASSUME_NONNULL_END
