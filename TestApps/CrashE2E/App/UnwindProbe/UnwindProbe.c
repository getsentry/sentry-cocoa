#include <dlfcn.h>
#include <execinfo.h>
#include <stdbool.h>
#include <string.h>

static _Thread_local bool armed;
static _Thread_local bool fired;
void
CrashE2EArmUnwindProbe(void)
{
    armed = true;
}
bool
CrashE2EUnwindProbeFired(void)
{
    return fired;
}

static bool
failCapture(void *caller)
{
    Dl_info info;
    if (!armed || !dladdr(caller, &info) || !info.dli_sname
        || strcmp(info.dli_sname, "kssc_initSelfThread"))
        return false;
    armed = false;
    fired = true;
    return true;
}
static size_t
probe(void **frames, size_t count, uint32_t *task)
{
    if (failCapture(__builtin_return_address(0)))
        return 0;
    return backtrace_async(frames, count, task);
}
__attribute__((used, section("__DATA,__interpose"))) static const struct {
    __typeof__(&backtrace_async) replacement, original;
} hook = { probe, backtrace_async };
