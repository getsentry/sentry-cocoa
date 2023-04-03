#import "SentryDefines.h"
#import "SentrySerializable.h"
#import <SentryUser.h>

@interface
SentryUser (Private)

/**
 * Initializes a SentryUser from a dictionary.
 * @param dictionary The dictionary containing user data.
 * @return The SentryUser or nil if initializing with the dictionary results in an error.
 */
- (nullable instancetype)initWithDictionary:(NSDictionary *_Nullable)dictionary;

@end
