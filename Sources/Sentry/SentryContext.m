//
//  SentryContext.m
//  Sentry
//
//  Created by Daniel Griesser on 18/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryContext.h>
#import <Sentry/SentryDefines.h>

#else
#import "SentryContext.h"
#import "SentryDefines.h"
#endif

#if SENTRY_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation SentryContext

- (instancetype)init {
    return [super init];
}

+ (instancetype)new {
    return [super new];
}

- (NSDictionary<NSString *,id> *)serialized {
    NSMutableDictionary *serializedData = [NSMutableDictionary new];
   
    if (nil == self.osContext) {
        self.osContext = [self generatedOsContext];
    }
    [serializedData setValue:self.osContext forKey:@"os"];
    
    if (nil == self.appContext) {
        self.appContext = [self generatedAppContext];
    }
    [serializedData setValue:self.appContext forKey:@"app"];
    
    if (nil == self.deviceContext) {
        self.deviceContext = [self generatedDeviceContext];
    }
    [serializedData setValue:self.deviceContext forKey:@"device"];
    
    return serializedData;
}

- (NSDictionary<NSString *,id> *)generatedOsContext {
    NSMutableDictionary *serializedData = [NSMutableDictionary new];
    
//    attributes.append(("build", build)) osVersion
//    attributes.append(("kernel_version", kernelVersion))
//    attributes.append(("rooted", jailbroken))
    
#if TARGET_OS_IPHONE
    [serializedData setValue:@"iOS" forKey:@"name"];
#elif TARGET_OS_OSX
    [serializedData setValue:@"macOS" forKey:@"name"];
#elif TARGET_OS_TV
    [serializedData setValue:@"tvOS" forKey:@"name"];
#elif TARGET_OS_WATCH
    [serializedData setValue:@"watchOS" forKey:@"name"];
#endif
    
#if SENTRY_HAS_UIDEVICE
    [serializedData setValue:[UIDevice currentDevice].systemVersion forKey:@"version"];
#else
    NSOperatingSystemVersion version = [NSProcessInfo processInfo].operatingSystemVersion;
    NSString *systemVersion = [NSString stringWithFormat:@"%d.%d.%d", (int)version.majorVersion, (int)version.minorVersion, (int)version.patchVersion];
    [serializedData setValue:systemVersion forKey:@"version"];
#endif
    
    return serializedData;
}

- (NSDictionary<NSString *,id> *)generatedDeviceContext {
    NSMutableDictionary *serializedData = [NSMutableDictionary new];
    
    /*
     attributes.append(("family", family))
     attributes.append(("arch", architecture))
     attributes.append(("model", model))
     attributes.append(("family", family))
     attributes.append(("free_memory", freeMemory))
     attributes.append(("memory_size", memorySize))
     attributes.append(("usable_memory", usableMemory))
     attributes.append(("storage_size", storageSize))
     attributes.append(("boot_time", bootTime))
     attributes.append(("timezone", timezone))
     
     switch (isOSX, isSimulator) {
     // macOS
     case (true, _):
     attributes.append(("model", machine))
     // iOS/tvOS/watchOS Sim
     case (false, true):
     
     // iOS/tvOS/watchOS Device
     default:
     attributes.append(("model_id", modelDetail))
     
     }
     */
#if TARGET_OS_SIMULATOR
    [serializedData setValue:@(YES) forKey:@"simulator"];
#endif
    
    
    return serializedData;
}

- (NSDictionary<NSString *,id> *)generatedAppContext {
    NSMutableDictionary *serializedData = [NSMutableDictionary new];
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];

    /*attributes.append(("app_start_time", appStartTime))
    attributes.append(("device_app_hash", deviceAppHash))
    attributes.append(("app_id", appID))
    attributes.append(("build_type", buildType))
    */
    
    [serializedData setValue:infoDict[@"CFBundleIdentifier"] forKey:@"app_identifier"];
    [serializedData setValue:infoDict[@"CFBundleName"] forKey:@"app_name"];
    [serializedData setValue:infoDict[@"CFBundleVersion"] forKey:@"app_build"];
    [serializedData setValue:infoDict[@"CFBundleShortVersionString"] forKey:@"app_version"];
    
    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
