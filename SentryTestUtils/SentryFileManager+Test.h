#import "SentryFileManager.h"

NS_ASSUME_NONNULL_BEGIN

BOOL isErrorPathTooLong(NSError *error);
BOOL createDirectoryIfNotExists(NSString *path, NSError **error);
NSString *_Nullable sentryGetScopedCachesDirectory(NSString *cachesDirectory);
NSString *_Nullable sentryBuildScopedCachesDirectoryPath(NSString *cachesDirectory,
    BOOL isSandboxed, NSString *_Nullable bundleIdentifier, NSString *_Nullable lastPathComponent);

SENTRY_EXTERN NSURL *_Nullable launchProfileConfigFileURL(void);
SENTRY_EXTERN NSURL *_Nullable sentryLaunchConfigFileURL;

@interface SentryFileManager ()

@property (nonatomic, copy) NSString *eventsPath;
@property (nonatomic, copy) NSString *envelopesPath;
@property (nonatomic, copy) NSString *timezoneOffsetFilePath;

- (void)clearDiskState;

@end

NS_ASSUME_NONNULL_END
