#import "SentryFileManager.h"

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN NSURL *launchProfileConfigFileURL(void);
SENTRY_EXTERN NSURL *_Nullable sentryLaunchConfigFileURL;

@interface
SentryFileManager ()

@property (nonatomic, copy) NSString *eventsPath;
@property (nonatomic, copy) NSString *envelopesPath;
@property (nonatomic, copy) NSString *timezoneOffsetFilePath;

@end

NS_ASSUME_NONNULL_END
