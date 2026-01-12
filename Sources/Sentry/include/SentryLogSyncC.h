#ifndef SentryLogSyncC_h
#define SentryLogSyncC_h

#include "SentryBatchBufferC.h"
#include <stdbool.h>

/**
 * Initializes the global log buffer that can be accessed during a crash.
 *
 * @param data_capacity Maximum capacity in bytes for storing data.
 * @param items_capacity Maximum number of items the buffer can hold.
 * @return true if initialization was successful, false otherwise.
 *
 * @note This function is NOT async-signal-safe and should only be called during SDK initialization.
 * @note Only one global buffer can exist at a time. Calling this again will destroy the previous
 * buffer.
 */
bool sentrycrash_logSync_start(size_t data_capacity, size_t items_capacity);

/**
 * Destroys the global log buffer and frees all associated memory.
 *
 * @note This function is NOT async-signal-safe.
 */
void sentrycrash_logSync_stop(void);

/**
 * Gets the global log buffer pointer.
 *
 * @return Pointer to the buffer, or NULL if not initialized.
 *
 * @note This function is async-signal-safe and can be called from the crash handler.
 */
SentryBatchBufferC *sentrycrash_logSync_getBuffer(void);

#endif /* SentryLogSyncC_h */
