#ifndef SentryThreadCrumb_h
#define SentryThreadCrumb_h

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/** The most characters a thread crumb spells. A UUID without hyphens has 32. */
#define SENTRY_THREADCRUMB_MAX_LENGTH 64

/**
 * Parks a thread whose call stack spells `message`, one frame per character, so a crash report
 * that holds the call stacks of all threads carries the message with it. Modeled on KSCrash's
 * `KSCrashThreadcrumb`.
 *
 * Only hexadecimal digits are spelled, case-insensitively; every other character is skipped. The
 * thread stays parked for the rest of the process, so every call costs one idle thread for good;
 * the caller parks one crumb per process.
 *
 * @param message The message to spell, at most `SENTRY_THREADCRUMB_MAX_LENGTH` spelled characters.
 * @param addresses Receives the return address of the frame of each spelled character, outermost
 * first, which is the order of the characters in the message.
 * @param addressesCount The capacity of `addresses`.
 * @return The number of addresses written, which is the number of spelled characters, or 0 when
 * nothing was spelled, the thread couldn't be created, `addresses` is too small, or the thread
 * didn't spell the message within five seconds. In the last case the thread still parks, so the
 * caller must not park another crumb.
 */
size_t sentry_threadcrumb_park(
    const char *_Nonnull message, uint64_t *_Nonnull addresses, size_t addressesCount);

#ifdef __cplusplus
}
#endif

#endif // SentryThreadCrumb_h
