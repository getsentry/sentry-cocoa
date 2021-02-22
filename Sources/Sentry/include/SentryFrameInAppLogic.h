#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * This class detects whether an image belongs to the app or not. We differentiate between three
 * different types of images.
 *
 * First, the main executable of the app, which's name can be retrieved by CFBundleExecutable. To
 * mark this image as inApp the caller needs to pass in the CFBundleExecutable to InAppIncludes.
 *
 * Next, there are private frameworks embedded in the application bundle. Both app supporting
 * frameworks as CocoaLumberJack, Sentry, RXSwift, etc., and frameworks written by the user fall
 * into this category. These frameworks can be both inApp or not. As we expect most frameworks of
 * this category to be supporting frameworks, we mark them not as inApp. If a user wants such a
 * framework to be inApp he needs to pass the name into inAppInclude. For dynamic frameworks, the
 * location is usually in the bundle under /Frameworks/FrameworkName.framework/FrameworkName. As for
 * static frameworks, the location is the same as the main executable; this class marks all static
 * frameworks as inApp. To remove static frameworks from being inApp, Sentry uses stack trace
 * grouping rules.
 *
 * Last, this class marks all public frameworks as not inApp. Such frameworks are bound dynamically
 * and are usually located at /Library/Frameworks or ~/Library/Frameworks. For simulators, the
 * location can be something like
 * /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/...
 *
 */
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
