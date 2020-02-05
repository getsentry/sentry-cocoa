//
//  SentryCrashInstallation.h
//  Sentry
//
//  Created by Daniel Griesser on 10/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SentryCrash.h"
#import "SentryCrashInstallation.h"

@interface SentryInstallation : SentryCrashInstallation

- (void)sendAllReports;

@end
