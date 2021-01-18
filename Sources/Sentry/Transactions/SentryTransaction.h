//
//  SentryTransaction.h
//  Sentry
//
//  Created by Dhiogo Brustolin on 11/01/21.
//  Copyright © 2021 Sentry. All rights reserved.
//

#import <Sentry/Sentry.h>

NS_ASSUME_NONNULL_BEGIN

@class SentrySpanContext, SentryTransactionContext, SentryHub;

@interface SentryTransaction : NSObject<SentrySerializable>
SENTRY_NO_INIT

@property (nonatomic, strong) SentryId *eventId;

/**
 * NSDate of when the transaction ended
 */
@property (nonatomic, strong) NSDate *timestamp;

/**
 * NSDate of when the transaction started
 */
@property (nonatomic, strong) NSDate *_Nullable startTimestamp;

/**
 * The current transaction (state) on the crash
 */
@property (nonatomic, copy) NSString *_Nullable transaction;

/**
 * Arbitrary key:value (string:string ) data that will be shown with the event
 */
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *_Nullable tags;

/**
 * Information about the sdk can be something like this. This will be set for
 * you Don't touch it if you not know what you are doing.
 *
 * {
 *  version: "6.0.1",
 *  name: "sentry.cocoa",
 *  integrations: [
 *      "react-native"
 *  ]
 * }
 */
@property (nonatomic, strong) NSDictionary<NSString *, id> *_Nullable sdk;

/**
 * This object contains meta information, will be set automatically overwrite
 * only if you know what you are doing
 */
@property (nonatomic, strong)
NSDictionary<NSString *, NSDictionary<NSString *, id> *> *_Nullable context;

//-(instancetype)initWithName:(NSString*)name;
-(instancetype)initWithTransactionContext:(SentryTransactionContext*)context andHub:(SentryHub*)hub;
-(instancetype)initWithName:(NSString*)name context:(SentrySpanContext*)context andHub:(SentryHub*)hub;
-(void)finish;

@end

NS_ASSUME_NONNULL_END
