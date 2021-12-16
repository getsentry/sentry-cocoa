#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
static NSString *const SENTRY_IO_WRITE_OPERATION = @"file.write";

static NSString *const SENTRY_IO_READ_OPERATION = @"file.write";

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


/**
 * Measure NSData 'initWithContentsOfFile:' method.
 */
- (NSData *)measureNSDataFromFile:(NSString *)path
                     method:(id (^)(NSString *))method;


/**
 * Measure NSData 'initWithContentsOfFile:options:error:' method.
 */
- (NSData *)measureNSDataFromFile:(NSString *)path
                    options:(NSDataReadingOptions)readOptionsMask
                      error:(NSError **)error
                     method:(id (^)(NSString *, NSDataReadingOptions, NSError **))method;

/**
 * Measure NSData 'initWithContentsOfURL:options:error:' method.
 */
- (NSData *)measureNSDataFromURL:(NSString *)url
                   options:(NSDataReadingOptions)readOptionsMask
                     error:(NSError **)error
                    method:(id (^)(NSString *, NSDataReadingOptions, NSError **))method;

@end

NS_ASSUME_NONNULL_END
