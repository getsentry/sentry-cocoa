#if SDK_V10

#    include <dlfcn.h>
#    include <exception>
#    include <typeinfo>

namespace {
using CxaThrow = void (*)(void *, std::type_info *, void (*)(void *));
using CxaRethrow = void (*)(void);

template <typename Function>
Function
resolveNextCxaFunction(const char *symbol)
{
    auto function = reinterpret_cast<Function>(dlsym(RTLD_NEXT, symbol));
    if (function == nullptr) {
        std::terminate();
    }
    return function;
}
} // namespace

extern "C" {

// Unity's weak C++ ABI wrappers hand off through these Sentry-named symbols. Resolving the next
// implementation skips those wrappers when they share the caller image, preventing the handoff
// from recursing back through Unity. KSCrash's terminate handler remains responsible for recording
// an uncaught exception whether __cxa_throw swapping is enabled or disabled.
[[noreturn]] __attribute__((visibility("default"))) void
__sentry_cxa_throw(void *thrownException, std::type_info *typeInfo, void (*destructor)(void *))
{
    static const CxaThrow cxaThrow = resolveNextCxaFunction<CxaThrow>("__cxa_throw");
    cxaThrow(thrownException, typeInfo, destructor);
    __builtin_unreachable();
}

[[noreturn]] __attribute__((visibility("default"))) void
__sentry_cxa_rethrow()
{
    static const CxaRethrow cxaRethrow = resolveNextCxaFunction<CxaRethrow>("__cxa_rethrow");
    cxaRethrow();
    __builtin_unreachable();
}

struct SentryCxaThrowCompatibilityFunctions {
    CxaThrow cxaThrow;
    CxaRethrow cxaRethrow;
};

__attribute__((visibility("hidden"))) const void *
sentry_cxa_throw_compatibility_linker_anchor()
{
    static const SentryCxaThrowCompatibilityFunctions functions
        = { __sentry_cxa_throw, __sentry_cxa_rethrow };
    return &functions;
}
}

#endif // SDK_V10
