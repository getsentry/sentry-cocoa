#import <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        int *pi = (int*)0x00001111;
        *pi = 17;
    }
    return 0;
}
