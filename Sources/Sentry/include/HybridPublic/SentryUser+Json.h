//
//  SentryUser+Json.h
//  Sentry
//
//  Created by Denis Andrašec on 20.03.23.
//  Copyright © 2023 Sentry. All rights reserved.
//

#import "SentryDefines.h"
#import "SentrySerializable.h"
#import <SentryUser.h>

@interface
SentryUser (Json)

/**
 * Initializes a SentryUser from a JSON object.
 * @param jsonObject The jsonObject containing the user.
 * @return The SentryUser or nil if the JSONObject contains an error.
 */
- (nullable instancetype)initWithJSONObject:(NSDictionary *_Nullable)jsonObject;

@end
