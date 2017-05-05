//
//  SentryUser.h
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryUser : NSObject

@property(nonatomic, copy) NSString *userID;
@property(nonatomic, copy) NSString *_Nullable email;
@property(nonatomic, copy) NSString *_Nullable username;
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable extra;

//- (nonnull instancetype)initWithId:(NSString * _Nonnull)userID email:(NSString * _Nullable)email username:(NSString * _Nullable)username extra:(NSDictionary<NSString *, id> * _Nonnull)extra;

@end

NS_ASSUME_NONNULL_END
