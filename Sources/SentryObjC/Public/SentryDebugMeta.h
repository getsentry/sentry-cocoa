#import <Foundation/Foundation.h>

#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Information about a loaded library and its memory address.
 *
 * Debug metadata helps Sentry symbolicate stack traces by identifying which
 * binaries were loaded and where they were mapped in memory. Each entry represents
 * one framework, library, or executable.
 *
 * @see SentryEvent
 */
@interface SentryDebugMeta : NSObject <SentrySerializable>

/**
 * Unique identifier for the debug information (dSYM UUID).
 *
 * Used to locate the correct debug symbols for symbolication.
 */
@property (nonatomic, copy, nullable) NSString *debugID;

/**
 * Type of debug information.
 *
 * Typically "macho" for iOS/macOS binaries.
 */
@property (nonatomic, copy, nullable) NSString *type;

/**
 * Size of the binary image in bytes.
 */
@property (nonatomic, copy, nullable) NSNumber *imageSize;

/**
 * Base memory address where the image was loaded.
 */
@property (nonatomic, copy, nullable) NSString *imageAddress;

/**
 * Virtual memory address of the image.
 */
@property (nonatomic, copy, nullable) NSString *imageVmAddress;

/**
 * Path to the binary file.
 */
@property (nonatomic, copy, nullable) NSString *codeFile;

/**
 * Creates a new debug metadata instance.
 *
 * @return A new debug metadata instance.
 */
- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
