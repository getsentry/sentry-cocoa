#import <Foundation/Foundation.h>

@protocol SentryObjCRuntimeWrapper <NSObject>

- (const char **)copyClassNamesForImage:(const char *)image amount:(unsigned int *)outCount;

@end
