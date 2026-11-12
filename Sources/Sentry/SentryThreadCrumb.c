// Modeled on KSCrash's KSCrashThreadcrumb (MIT), which is inspired by Embrace's EMBThreadcrumb and
// Naftaly's Threadcrumb. The SDK has its own encoder so that V9 and V10 share one, and so that the
// decoder knows the exact shape of the stack.

#include "SentryThreadCrumb.h"

#include <ctype.h>
#include <dispatch/dispatch.h>
#include <execinfo.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>

// Every character has to be its own frame: no inlining, and no tail calls, which would replace the
// caller's frame with the callee's.
#define SENTRY_THREADCRUMB_KEEP_FRAME __attribute__((disable_tail_calls))
#define SENTRY_THREADCRUMB_NOINLINE __attribute__((noinline))
#define SENTRY_THREADCRUMB_THWART_TAIL_CALL __asm__ __volatile__("")

typedef struct {
    char message[SENTRY_THREADCRUMB_MAX_LENGTH + 1];
    size_t length;
    size_t index;
    uint64_t addresses[SENTRY_THREADCRUMB_MAX_LENGTH];
    size_t addressesCount;
    dispatch_semaphore_t spelled;
    dispatch_semaphore_t park;
} sentry_threadcrumb_t;

typedef void (*sentry_threadcrumb_func_t)(sentry_threadcrumb_t *crumb);

static sentry_threadcrumb_func_t sentry_threadcrumb_lookup(char c);

/**
 * The innermost frame: records the frames of the characters, tells the caller the stack is shaped
 * and parks the thread for the rest of the process.
 */
static SENTRY_THREADCRUMB_NOINLINE void
__sentry_threadcrumb_end__(sentry_threadcrumb_t *crumb) SENTRY_THREADCRUMB_KEEP_FRAME
{
    void *frames[SENTRY_THREADCRUMB_MAX_LENGTH + 8];
    int count = backtrace(frames, sizeof(frames) / sizeof(frames[0]));

    // frames[0] is this function. The next frames are the character functions, innermost first,
    // so the last character comes first. The caller checks that every character got a frame.
    size_t available = count > 1 ? (size_t)(count - 1) : 0;
    size_t length = crumb->length < available ? crumb->length : available;
    for (size_t i = 0; i < length; i++) {
        crumb->addresses[length - 1 - i] = (uint64_t)(uintptr_t)frames[1 + i];
    }
    crumb->addressesCount = length;

    dispatch_semaphore_signal(crumb->spelled);
    dispatch_semaphore_wait(crumb->park, DISPATCH_TIME_FOREVER);
    SENTRY_THREADCRUMB_THWART_TAIL_CALL;
}

#define SENTRY_THREADCRUMB_NEXT(crumb)                                                             \
    do {                                                                                           \
        sentry_threadcrumb_func_t next                                                             \
            = sentry_threadcrumb_lookup((crumb)->message[(crumb)->index]);                         \
        (crumb)->index++;                                                                          \
        if (next != NULL) {                                                                        \
            next(crumb);                                                                           \
        } else {                                                                                   \
            __sentry_threadcrumb_end__(crumb);                                                     \
        }                                                                                          \
    } while (0)

#define SENTRY_THREADCRUMB_CHAR(c)                                                                 \
    static SENTRY_THREADCRUMB_NOINLINE void __sentry_threadcrumb_##c##__(                          \
        sentry_threadcrumb_t *crumb) SENTRY_THREADCRUMB_KEEP_FRAME                                 \
    {                                                                                              \
        SENTRY_THREADCRUMB_NEXT(crumb);                                                            \
        SENTRY_THREADCRUMB_THWART_TAIL_CALL;                                                       \
    }

// One function per hexadecimal digit, so the spelled frames resolve to their digit when the stack
// is symbolicated, and the decoder can match them by address without symbolication.
// clang-format off
SENTRY_THREADCRUMB_CHAR(0) SENTRY_THREADCRUMB_CHAR(1) SENTRY_THREADCRUMB_CHAR(2) SENTRY_THREADCRUMB_CHAR(3)
SENTRY_THREADCRUMB_CHAR(4) SENTRY_THREADCRUMB_CHAR(5) SENTRY_THREADCRUMB_CHAR(6) SENTRY_THREADCRUMB_CHAR(7)
SENTRY_THREADCRUMB_CHAR(8) SENTRY_THREADCRUMB_CHAR(9) SENTRY_THREADCRUMB_CHAR(A) SENTRY_THREADCRUMB_CHAR(B)
SENTRY_THREADCRUMB_CHAR(C) SENTRY_THREADCRUMB_CHAR(D) SENTRY_THREADCRUMB_CHAR(E) SENTRY_THREADCRUMB_CHAR(F)
// clang-format on

#undef SENTRY_THREADCRUMB_CHAR

    // Filled at runtime so the compiler can't turn the indirect call in the character functions
    // into one direct call per digit, which would give every digit sixteen return addresses instead
    // of one.
    static sentry_threadcrumb_func_t sentry_threadcrumb_table[128];
static dispatch_once_t sentry_threadcrumb_table_once;

static void
sentry_threadcrumb_fill_table(void *context)
{
    (void)context;
    // The terminator goes through the same indirect call as the digits, so every digit returns
    // from one call site whether or not it is the last one.
    sentry_threadcrumb_table['\0'] = __sentry_threadcrumb_end__;
    sentry_threadcrumb_table['0'] = __sentry_threadcrumb_0__;
    sentry_threadcrumb_table['1'] = __sentry_threadcrumb_1__;
    sentry_threadcrumb_table['2'] = __sentry_threadcrumb_2__;
    sentry_threadcrumb_table['3'] = __sentry_threadcrumb_3__;
    sentry_threadcrumb_table['4'] = __sentry_threadcrumb_4__;
    sentry_threadcrumb_table['5'] = __sentry_threadcrumb_5__;
    sentry_threadcrumb_table['6'] = __sentry_threadcrumb_6__;
    sentry_threadcrumb_table['7'] = __sentry_threadcrumb_7__;
    sentry_threadcrumb_table['8'] = __sentry_threadcrumb_8__;
    sentry_threadcrumb_table['9'] = __sentry_threadcrumb_9__;
    sentry_threadcrumb_table['A'] = __sentry_threadcrumb_A__;
    sentry_threadcrumb_table['B'] = __sentry_threadcrumb_B__;
    sentry_threadcrumb_table['C'] = __sentry_threadcrumb_C__;
    sentry_threadcrumb_table['D'] = __sentry_threadcrumb_D__;
    sentry_threadcrumb_table['E'] = __sentry_threadcrumb_E__;
    sentry_threadcrumb_table['F'] = __sentry_threadcrumb_F__;
}

static sentry_threadcrumb_func_t
sentry_threadcrumb_lookup(char c)
{
    unsigned char index = (unsigned char)c;
    if (index >= sizeof(sentry_threadcrumb_table) / sizeof(sentry_threadcrumb_table[0])) {
        return NULL;
    }
    return sentry_threadcrumb_table[index];
}

static SENTRY_THREADCRUMB_NOINLINE void *
__sentry_threadcrumb_start__(void *arg) SENTRY_THREADCRUMB_KEEP_FRAME
{
    sentry_threadcrumb_t *crumb = arg;
    pthread_setname_np("io.sentry.threadcrumb");
    SENTRY_THREADCRUMB_NEXT(crumb);
    SENTRY_THREADCRUMB_THWART_TAIL_CALL;
    return NULL;
}

size_t
sentry_threadcrumb_park(const char *message, uint64_t *addresses, size_t addressesCount)
{
    // The thread stays parked for the rest of the process and keeps pointing at the crumb, so the
    // crumb is never freed.
    sentry_threadcrumb_t *crumb = calloc(1, sizeof(sentry_threadcrumb_t));
    if (crumb == NULL) {
        return 0;
    }

    for (const char *c = message; *c != '\0' && crumb->length < SENTRY_THREADCRUMB_MAX_LENGTH;
        c++) {
        if (isxdigit((unsigned char)*c)) {
            crumb->message[crumb->length++] = (char)toupper((unsigned char)*c);
        }
    }
    if (crumb->length == 0 || addressesCount < crumb->length) {
        free(crumb);
        return 0;
    }

    dispatch_once_f(&sentry_threadcrumb_table_once, NULL, sentry_threadcrumb_fill_table);
    crumb->spelled = dispatch_semaphore_create(0);
    crumb->park = dispatch_semaphore_create(0);

    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    pthread_attr_set_qos_class_np(&attr, QOS_CLASS_UTILITY, 0);
    pthread_t thread;
    int created = pthread_create(&thread, &attr, __sentry_threadcrumb_start__, crumb);
    pthread_attr_destroy(&attr);
    if (created != 0) {
        free(crumb);
        return 0;
    }

    // The thread only has to recurse a few dozen frames, so a bounded wait keeps a starved thread
    // from holding up SDK start; the thread still parks on its own when it gets there.
    if (dispatch_semaphore_wait(crumb->spelled, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC))
        != 0) {
        return 0;
    }
    if (crumb->addressesCount != crumb->length) {
        return 0;
    }

    memcpy(addresses, crumb->addresses, crumb->length * sizeof(uint64_t));
    return crumb->length;
}
