#import "SentryCrashDynamicLinker.h"
#import <Foundation/Foundation.h>

void binaryImageWasAdded(const SentryCrashBinaryImage *_Nullable image);

void binaryImageWasRemoved(const SentryCrashBinaryImage *_Nullable image);
