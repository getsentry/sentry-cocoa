#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Contains information about a loaded library in the process and the memory address.
 * @discussion Since 8.2.0, the SDK changed the debug image type from "apple" to "macho". For macho,
 * the SDK now sends @c debugID instead of @c uuid, and @c codeFile instead of @c name. For more
 * information check https://develop.sentry.dev/sdk/event-payloads/debugmeta/#mach-o-images.
 */
@interface SentryObjCDebugMeta : NSObject

/**
 * Identifier of the dynamic library or executable. It is the value of the @c LC_UUID load command
 * in the Mach header, formatted as UUID.
 */
@property (nonatomic, copy, nullable) NSString *debugID;

/// Type of debug meta. We highly recommend using "macho"; was "apple" previously.
@property (nonatomic, copy, nullable) NSString *type;

/**
 * The size of the image in virtual memory. If missing, Sentry will assume that the image spans up
 * to the next image, which might lead to invalid stack traces.
 */
@property (nonatomic, copy, nullable) NSNumber *imageSize;

/**
 * Memory address, at which the image is mounted in the virtual address space of the process. Should
 * be a string in hex representation prefixed with "0x".
 */
@property (nonatomic, copy, nullable) NSString *imageAddress;

/**
 * Raw numeric memory address at which the image is mounted.
 * @note This is the same value as @c imageAddress but as a @c uint64_t instead of a hex string.
 */
@property (nonatomic, assign) uint64_t imageAddressRaw;

/**
 * Preferred load address of the image in virtual memory, as declared in the headers of the image.
 * When loading an image, the operating system may still choose to place it at a different address.
 */
@property (nonatomic, copy, nullable) NSString *imageVmAddress;

/**
 * Raw numeric preferred load address of the image in virtual memory.
 * @note This is the same value as @c imageVmAddress but as a @c uint64_t instead of a hex string.
 */
@property (nonatomic, assign) uint64_t imageVmAddressRaw;

/// The path to the code file (executable or library).
@property (nonatomic, copy, nullable) NSString *codeFile;

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
