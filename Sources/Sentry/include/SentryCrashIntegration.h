//
//  SentryCrashIntegration.h
//  Sentry
//
//  Created by Klemens Mantzos on 04.12.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SentryIntegrationProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryCrashIntegration : NSObject <SentryIntegrationProtocol>

/**
 * This function tries to start the SentryCrash handler, return YES if successfully started
 * otherwise it will return false and set error
 *
 * @param error if SentryCrash is not available error will be set
 * @return successful
 */
- (BOOL)startCrashHandlerWithError:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
