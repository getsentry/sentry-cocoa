//
//  ExceptionCatcher.h
//  Sentry
//
//  Created by Itay Brenner on 27/5/25.
//  Copyright © 2025 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NSException;

@interface ExceptionCatcher : NSObject

+ (NSException *_Nullable)tryBlock:(void (^)(void))tryBlock;

@end

NS_ASSUME_NONNULL_END
