#import "FileUtils.h"
#import "SentryError.h"
#import "SentryLog.h"

BOOL
isErrorPathTooLong(NSError *error)
{
    NSError *underlyingError = NULL;
    if (@available(macOS 11.3, iOS 14.5, watchOS 7.4, tvOS 14.5, *)) {
        underlyingError = error.underlyingErrors.firstObject;
    }
    if (underlyingError == NULL) {
        id errorInUserInfo = [error.userInfo valueForKey:NSUnderlyingErrorKey];
        if (errorInUserInfo && [errorInUserInfo isKindOfClass:[NSError class]]) {
            underlyingError = errorInUserInfo;
        }
    }
    if (underlyingError == NULL) {
        underlyingError = error;
    }
    BOOL isEnameTooLong
        = underlyingError.domain == NSPOSIXErrorDomain && underlyingError.code == ENAMETOOLONG;
    // On older OS versions the error code is NSFileWriteUnknown
    // Reference: https://developer.apple.com/forums/thread/128927?answerId=631839022#631839022
    BOOL isUnknownError = underlyingError.domain == NSCocoaErrorDomain
        && underlyingError.code == NSFileWriteUnknownError;

    return isEnameTooLong || isUnknownError;
}

BOOL
createDirectoryIfNotExists(NSString *path, NSError **error)
{
    BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:path
                                             withIntermediateDirectories:YES
                                                              attributes:nil
                                                                   error:error];
    if (success) {
        return YES;
    }

    if (isErrorPathTooLong(*error)) {
        SENTRY_LOG_FATAL(@"Failed to create directory, path is too long: %@", path);
    }
    *error = NSErrorFromSentryErrorWithUnderlyingError(kSentryErrorFileIO,
        [NSString stringWithFormat:@"Failed to create the directory at path %@.", path], *error);
    return NO;
}

NSString *_Nullable sentryBuildScopedCachesDirectoryPath(NSString *cachesDirectory,
    BOOL isSandboxed, NSString *_Nullable bundleIdentifier, NSString *_Nullable lastPathComponent)
{
    // If the app is sandboxed, we can just use the provided caches directory.
    if (isSandboxed) {
        return cachesDirectory;
    }

    // If the macOS app is not sandboxed, we need to manually create a scoped cache
    // directory. The cache path must be unique an stable over app launches, therefore we
    // can not use any changing identifier.
    SENTRY_LOG_DEBUG(
        @"App is not sandboxed, extending default cache directory with bundle identifier.");
    NSString *_Nullable identifier = bundleIdentifier;
    if (identifier == nil) {
        SENTRY_LOG_WARN(@"No bundle identifier found, using main bundle executable name.");
        identifier = lastPathComponent;
    } else if (identifier.length == 0) {
        SENTRY_LOG_WARN(@"Bundle identifier exists but is zero length, using main bundle "
                        @"executable name.");
        identifier = lastPathComponent;
    }

    // If neither the bundle identifier nor the executable name are available, we can't
    // create a unique and stable cache directory.
    // We do not fall back to any default path, because it could be shared with other apps
    // and cause leaks impacting other apps.
    if (identifier == nil) {
        SENTRY_LOG_ERROR(@"No bundle identifier found, cannot create cache directory.");
        return nil;
    }

    // It's unlikely that the executable name will be zero length, but we'll cover this case anyways
    if (identifier.length == 0) {
        SENTRY_LOG_ERROR(@"Executable name was zero length.");
        return nil;
    }

    return [cachesDirectory stringByAppendingPathComponent:identifier];
}

NSString *_Nullable sentryGetScopedCachesDirectory(NSString *cachesDirectory)
{
#if !TARGET_OS_OSX
    // iOS apps are always sandboxed, therefore we can just early-return with the provided caches
    // directory.
    return cachesDirectory;
#else

    // For macOS apps, we need to ensure our own sandbox so that this path is not shared between
    // all apps that ship the SDK.

    // We can not use the SentryNSProcessInfoWrapper here because this method is called before
    // the SentryDependencyContainer is initialized.
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];

    // Only apps running in a sandboxed environment have the `APP_SANDBOX_CONTAINER_ID` set as a
    // process environment variable. Reference implementation:
    // https://github.com/realm/realm-js/blob/a03127726939f08f608edbdb2341605938f25708/packages/realm/binding/apple/platform.mm#L58-L74
    BOOL isSandboxed = processInfo.environment[@"APP_SANDBOX_CONTAINER_ID"] != nil;

    // The bundle identifier is used to create a unique cache directory for the app.
    // If the bundle identifier is not available, we use the name of the executable.
    // Note: `SentryCrash.getBundleName` is using `CFBundleName` to create a scoped directory.
    //       That value can be absent, therefore we use a more stable approach here.
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    NSString *lastPathComponent = [[[NSBundle mainBundle] executablePath] lastPathComponent];

    // Due to `NSProcessInfo` and `NSBundle` not being mockable in unit tests, we extract only the
    // logic to a separate function.
    return sentryBuildScopedCachesDirectoryPath(
        cachesDirectory, isSandboxed, bundleIdentifier, lastPathComponent);
#endif
}

/**
 * @note This method must be statically accessible because it will be called during app launch,
 * before any instance of  ``SentryFileManager`` exists, and so wouldn't be able to access this path
 * from an objc property on it like the other paths.
 */
NSString *_Nullable sentryStaticCachesPath(void)
{
    static NSString *_Nullable sentryStaticCachesPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // We request the users cache directory from Foundation.
        // For iOS apps and macOS apps with sandboxing, this path will be scoped for the current
        // app. For macOS apps without sandboxing, this path is not scoped and will be shared
        // between all apps.
        NSString *_Nullable cachesDirectory
            = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)
                  .firstObject;
        if (cachesDirectory == nil) {
            SENTRY_LOG_WARN(@"No caches directory location reported.");
            return;
        }

        // We need to ensure our own scoped directory so that this path is not shared between other
        // apps on the same system.
        NSString *_Nullable scopedCachesDirectory = sentryGetScopedCachesDirectory(cachesDirectory);
        if (!scopedCachesDirectory) {
            SENTRY_LOG_WARN(@"Failed to get scoped static caches directory.");
            return;
        }
        sentryStaticCachesPath = scopedCachesDirectory;
        SENTRY_LOG_DEBUG(@"Using static cache directory: %@", sentryStaticCachesPath);
    });
    return sentryStaticCachesPath;
}
