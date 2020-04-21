//
//  AppDelegate.m
//  Example-objc
//
//  Created by Daniel Griesser on 03.03.20.
//  Copyright © 2020 Sentry. All rights reserved.
//

#import "AppDelegate.h"
@import Sentry;

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    [SentrySDK startWithOptions:@{
        @"dsn": @"https://8ee5199a90354faf995292b15c196d48@o19635.ingest.sentry.io/4394",
        @"debug": @(YES),
        @"logLevel": @"verbose",
        @"enableAutoSessionTracking": @(YES),
        @"sessionTrackingIntervalMillis": @5000 // 5 seconds session timeout for testing
    }];
    return YES;
}


#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}


@end
