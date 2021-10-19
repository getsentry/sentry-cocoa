#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
static NSString *const SENTRY_IO_WRITE_OPERATION = @"file.write";

@interface SentryNSDataTracker : NSObject

@property (class, readonly, nonatomic) SentryNSDataTracker *sharedInstance;

- (void)enable;

- (void)disable;

/**
 * Measure NSData 'writeToFile:atomicall:' method.
 */
- (BOOL)measureNSData:(NSData *)data
          writeToFile:(NSString *)path
           atomically:(BOOL)useAuxiliaryFile
               method:(BOOL (^)(NSString *, BOOL))method;

/**
 * Measure NSData 'writeToFile:options:error:' method.
 */
- (BOOL)measureNSData:(NSData *)data
          writeToFile:(NSString *)path
              options:(NSDataWritingOptions)writeOptionsMask
                error:(NSError **)error
               method:(BOOL (^)(NSString *, NSDataWritingOptions, NSError **))method;

@end

NS_ASSUME_NONNULL_END
