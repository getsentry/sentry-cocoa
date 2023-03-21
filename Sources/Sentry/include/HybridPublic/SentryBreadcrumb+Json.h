//
//  SentryBreadcrumb+Json.h
//  Sentry
//
//  Created by Denis Andrašec on 21.03.23.
//  Copyright © 2023 Sentry. All rights reserved.
//

#import "SentryDefines.h"
#import "SentrySerializable.h"

@interface
SentryBreadcrumb (Json)

/**
 * Initializes a SentryBreadcrumb from a JSON object.
 * @param jsonObject The jsonObject containing the breadcrumb.
 * @return The SentryBreadcrumb or nil if the JSONObject contains an error.
 */
- (nullable instancetype)initWithJSONObject:(NSDictionary *_Nullable)jsonObject;

@end
