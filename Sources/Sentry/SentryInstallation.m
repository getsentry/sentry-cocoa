#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryInstallation.h>
#import <Sentry/SentryDefines.h>
#import "SentryUser.h"
#else
#import "SentryInstallation.h"
#import "SentryDefines.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation SentryInstallation

+ (NSString *)id {
    @synchronized (self) {
        NSString *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;

        NSString *installationFilePath = [cachePath stringByAppendingPathComponent:@"INSTALLATION"];

        NSData* installationData = [NSData dataWithContentsOfFile:installationFilePath];
        NSString* installationString = [[NSString alloc] initWithData:installationData encoding:NSUTF8StringEncoding];

        if (nil == installationString) {
            installationString = [NSUUID UUID].UUIDString;
            NSData *installationData = [installationString dataUsingEncoding:NSUTF8StringEncoding];
            NSFileManager *fileManager = [NSFileManager defaultManager];
            [fileManager createFileAtPath:installationFilePath
                                 contents:installationData
                               attributes:nil];
        }

        return installationString;
    }
}

@end

NS_ASSUME_NONNULL_END
