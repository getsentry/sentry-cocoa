#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryStacktrace;

@interface SentryFileIOTrackerHelper : NSObject
SENTRY_NO_INIT

- (instancetype)initWithThreadInspector:(SentryStacktrace *_Nullable (^)(void))stacktraceRetrieval;

- (void)enable;

- (void)disable;

/**
 * Measure NSData 'writeToFile:atomicall:' method.
 */
- (BOOL)measureNSData:(NSData *)data
             writeToFile:(NSString *)path
              atomically:(BOOL)useAuxiliaryFile
                  origin:(NSString *)origin
    processDirectoryPath:(NSString *)processDirectoryPath
                  method:(BOOL (^)(NSString *, BOOL))method;

/**
 * Measure NSData 'writeToFile:options:error:' method.
 */
- (BOOL)measureNSData:(NSData *)data
             writeToFile:(NSString *)path
                 options:(NSDataWritingOptions)writeOptionsMask
                  origin:(NSString *)origin
    processDirectoryPath:(NSString *)processDirectoryPath
                   error:(NSError **)error
                  method:(BOOL (^)(NSString *, NSDataWritingOptions, NSError **))method;

/**
 * Measure NSData 'initWithContentsOfFile:options:' method.
 */
- (void)measureNSDataFromFile:(NSString *)path
                       origin:(NSString *)origin
         processDirectoryPath:(NSString *)processDirectoryPath
                       method:(NSNumber *_Nullable (^)(void))method;

/**
 * Measure NSData 'initWithContentsOfURL:options:error:' method.
 */
- (void)measureNSDataFromURL:(NSURL *)url
                      origin:(NSString *)origin
        processDirectoryPath:(NSString *)processDirectoryPath
                      method:(NSNumber * (^)(void))method;

/**
 * Measure NSFileManager 'createFileAtPath:contents:attributes::' method.
 */
- (BOOL)measureNSFileManagerCreateFileAtPath:(NSString *)path
                                        data:(NSData *)data
                                  attributes:(NSDictionary<NSFileAttributeKey, id> *)attributes
                                      origin:(NSString *)origin
                        processDirectoryPath:(NSString *)processDirectoryPath
                                      method:(BOOL (^)(NSString *, NSData *,
                                                 NSDictionary<NSFileAttributeKey, id> *))method;

/**
 * Measure NSFileHandle 'readDataOfLength:' method.
 */
- (NSData *)measureNSFileHandle:(NSFileHandle *)fileHandle
               readDataOfLength:(NSUInteger)length
                         origin:(NSString *)origin
           processDirectoryPath:(NSString *)processDirectoryPath
                         method:(NSData * (^)(NSUInteger))method;

/**
 * Measure NSFileHandle 'readDataToEndOfFile' method.
 */
- (NSData *)measureNSFileHandle:(NSFileHandle *)fileHandle
            readDataToEndOfFile:(NSString *)origin
           processDirectoryPath:(NSString *)processDirectoryPath
                         method:(NSData * (^)(void))method;

/**
 * Measure NSFileHandle 'writeData:' method.
 */
- (void)measureNSFileHandle:(NSFileHandle *)fileHandle
                  writeData:(NSData *)data
                     origin:(NSString *)origin
       processDirectoryPath:(NSString *)processDirectoryPath
                     method:(void (^)(NSData *))method;

/**
 * Measure NSFileHandle 'synchronizeFile' method.
 */
- (void)measureNSFileHandle:(NSFileHandle *)fileHandle
            synchronizeFile:(NSString *)origin
       processDirectoryPath:(NSString *)processDirectoryPath
                     method:(void (^)(void))method;

// MARK: - Internal Methods available for Swift Extension

- (nullable id<SentrySpan>)spanForPath:(NSString *)path
                                origin:(NSString *)origin
                             operation:(NSString *)operation
                  processDirectoryPath:(NSString *)processDirectoryPath;

- (nullable id<SentrySpan>)spanForPath:(NSString *)path
                                origin:(NSString *)origin
                             operation:(NSString *)operation
                  processDirectoryPath:(NSString *)processDirectoryPath
                                  size:(NSUInteger)size;

@end

NS_ASSUME_NONNULL_END
