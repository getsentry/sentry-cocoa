#import "SentryNetworkBodyWarning.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents a captured network request or response body with optional warnings.
 * Mirrors sentry-java NetworkBody class.
 */
@interface SentryNetworkBody : NSObject

/**
 * The captured body content. May be nil if body could not be captured.
 * For JSON: NSDictionary or NSArray (parsed JSON)
 * For text: NSString
 * For form-urlencoded: NSDictionary
 */
@property (nonatomic, strong, readonly, nullable)
    id body; // OK: Can hold multiple body types (NSString, NSDictionary, NSData)

/** List of warnings encountered during body capture/parsing. May be nil. */
@property (nonatomic, strong, readonly, nullable) NSArray<NSNumber *> *warnings;

- (instancetype)initWithBody:(nullable id)body;
- (instancetype)initWithBody:(nullable id)body
                    warnings:(nullable NSArray<NSNumber *> *)warnings NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/** Serializes to dictionary for inclusion in breadcrumb data. */
- (NSDictionary *)serialize;

@end

NS_ASSUME_NONNULL_END
