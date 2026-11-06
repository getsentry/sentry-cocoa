#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A weak-key, strong-value map backed by a hash dictionary and a doubly linked cleanup list.
 * Each access inspects a bounded number of entries for dead keys. Values for dead keys remain
 * retained until cleanup reaches them or an explicit call to prune.
 */
@interface SentryWeakMap<KeyType, ObjectType> : NSObject

/**
 * Returns the value associated with a given key.
 *
 * - Parameter aKey: The key for which to return the corresponding value.
 * - Returns: The value associated with aKey, or nil if no value is associated with aKey.
 */
- (nullable ObjectType)objectForKey:(nullable KeyType)aKey;

/**
 * Adds a given key-value pair to the map table.
 *
 * -  Parameters:
 *   - anObject: The value for aKey.
 *   - aKey: The key for anObject.
 */
- (void)setObject:(nullable ObjectType)anObject forKey:(nullable KeyType)aKey;

/**
 * Removes the object for the given key.
 *
 * Does nothing if `aKey` does not exist.
 *
 * - Parameter aKey: The key to remove.
 */
- (void)removeObjectForKey:(nullable KeyType)aKey;

/**
 * Prune the maps to remove any weak references that have been deallocated.
 *
 * - SeeAlso: Further discussion available at
 * https://github.com/getsentry/sentry-cocoa/pull/5048#issuecomment-2876880446
 */
- (void)prune;

/**
 * The number of key-value pairs in the map table.
 */
- (NSUInteger)count;

@end

NS_ASSUME_NONNULL_END
