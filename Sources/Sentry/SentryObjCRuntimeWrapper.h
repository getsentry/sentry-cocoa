#import <Foundation/Foundation.h>

@protocol SentryObjCRuntimeWrapper <NSObject>

- (int)getClassList:(__unsafe_unretained Class *)buffer bufferCount:(int)bufferCount;

- (Class)getSuperclass:(Class)cls;

@end
