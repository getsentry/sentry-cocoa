#import "SentryFileManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryFileManager ()

@property (nonatomic, copy) NSString *eventsPath;
@property (nonatomic, copy) NSString *envelopesPath;
@property (nonatomic, copy) NSString *timezoneOffsetFilePath;

+ (NSString *)sentryApplicationSupportPath;
@end

NS_ASSUME_NONNULL_END
