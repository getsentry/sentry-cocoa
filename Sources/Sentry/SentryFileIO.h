#ifndef SentryFileIO_h
#define SentryFileIO_h

#include <stdbool.h>
#include <stddef.h>

bool sentryFileIO_writeBytesToFD(int fd, const void *bytes, size_t length);

bool sentryFileIO_readBytesFromFD(int fd, void *bytes, size_t length);

#endif /* SentryFileIO_h */
