#import "SentryDemangler.h"
#import "swift/Demangling/Demangle.h"

using namespace swift::Demangle;

@implementation SentryDemangler {
    Context ctx;
    DemangleOptions opt;
    NSMutableDictionary<NSString *, NSString *> * _cache;
}

- (instancetype)init {
    if(self = [super init]){
        opt = DemangleOptions::SimplifiedUIDemangleOptions();
        opt.DisplayModuleNames = true;
        
        _cache = [[NSMutableDictionary alloc]  init];
    }
    return self;
}

- (NSString *)demangleClassName:(NSString *)mangledName {
    NSString *result;
    
    @synchronized (_cache) {
        result = _cache[mangledName];
        
        if (!result) {
            const char * cString = [mangledName UTF8String];
            
            auto demangledName = ctx.demangleSymbolAsString(llvm::StringRef(cString),opt);
            ctx.clear();
            _cache[mangledName] = result = [NSString stringWithUTF8String:demangledName.c_str()];
        }
    }
    
    return result;
}

- (BOOL)isMangled:(NSString *)name {
    @synchronized (_cache) {
        if (_cache[name]) return YES;
        return isMangledName(llvm::StringRef([name UTF8String])) == true;
    }
}


@end
