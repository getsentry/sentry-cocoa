#import <Foundation/Foundation.h>

@protocol SentryObjCRuntimeWrapper <NSObject>

- (int)getClassList:(__unsafe_unretained Class *)buffer bufferCount:(int)bufferCount;

- (const char **)copyClassNamesForImage:(const char *)image amount:(unsigned int *)outCount;

- (void)countIterateClasses;

@end
