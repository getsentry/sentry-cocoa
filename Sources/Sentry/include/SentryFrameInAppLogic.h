#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryFrameInAppLogic : NSObject
SENTRY_NO_INIT

/**
 * Initializes SentryFrameInAppLogic with inAppIncludes and inAppExcludes.
 *
 * To work properly for Apple applications the inAppIncludes should contain the CFBundleExecutable,
 * which is the name of the bundle’s executable file.
 *
 * @param inAppIncludes A list of string suffixes of image names that belong to the app. This option
 * takes precedence over inAppExcludes.
 * @param inAppExcludes A list of string suffixes of image names that do not belong to the app, but
 * rather to third-party packages. Modules considered not part of the app will be hidden from stack
 * traces by default.
 */
- (instancetype)initWithInAppIncludes:(NSArray<NSString *> *)inAppIncludes
                        inAppExcludes:(NSArray<NSString *> *)inAppExcludes;

/**
 * Determines if the image belongs to the app by using inAppIncludes and inAppExcludes.
 *
 * @param imageName the full path of the image.
 *
 * @return YES if the imageName ends with a suffix of inAppIncludes. NO if the imageName doesn't end
 * with a suffix of inAppIncludes or if the imageName ends with a suffix of inAppExcludes.
 */
- (BOOL)isInApp:(NSString *)imageName;

@end

NS_ASSUME_NONNULL_END
