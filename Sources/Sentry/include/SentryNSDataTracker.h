#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
static NSString *const SENTRY_IO_OPERATION = @"IO";

@interface SentryNSDataTracker : NSObject

@property (class, readonly, nonatomic) SentryNSDataTracker *sharedInstance;

- (void)enable;

- (void)disable;

- (BOOL)traceWriteToFile:(NSString *)path
              atomically:(BOOL)useAuxiliaryFile
                  method:(BOOL (^)(NSString *, BOOL))method;

- (BOOL)traceWriteToFile:(NSString *)path
                 options:(NSDataWritingOptions)writeOptionsMask
                   error:(NSError * *)error
                  method:(BOOL (^)(NSString *, NSDataWritingOptions, NSError * *))method;

@end

NS_ASSUME_NONNULL_END
