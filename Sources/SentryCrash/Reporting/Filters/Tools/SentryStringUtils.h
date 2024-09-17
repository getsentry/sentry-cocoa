#ifndef Sentry_StringUtils_h
#define Sentry_StringUtils_h
#include <string.h>

/**
 * @brief Copies a string safely ensuring null-termination.
 *
 * This function copies up to `n-1` characters from the `src` string to
 * the `dst` buffer and ensures that the `dst` string is null-terminated.
 * It behaves similarly to `strncpy`, but guarantees null-termination.
 *
 * @param dst The destination buffer where the string will be copied.
 * @param src The source string to copy from.
 * @param n The size of the destination buffer, including space for the null terminator.
 *
 * @return Returns the destination.
 *
 * @note Ensure that `n` is greater than 0.
 * This can silently truncate src if it is larger than `n` - 1.
 */
static inline char *
strncpy_safe(char *dst, const char *src, size_t n)
{
    strncpy(dst, src, n - 1);
    dst[n - 1] = '\0';
    return dst;
}

#endif
