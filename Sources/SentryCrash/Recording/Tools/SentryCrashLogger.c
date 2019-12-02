//
//  SentryCrashLogger.c
//
//  Created by Karl Stenerud on 11-06-25.
//
//  Copyright (c) 2011 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//


#include "SentryCrashLogger.h"
#include "SentryCrashSystemCapabilities.h"

// ===========================================================================
#pragma mark - Common -
// ===========================================================================

#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>


// Compiler hints for "if" statements
#define likely_if(x) if(__builtin_expect(x,1))
#define unlikely_if(x) if(__builtin_expect(x,0))


/** The buffer size to use when writing log entries.
 *
 * If this value is > 0, any log entries that expand beyond this length will
 * be truncated.
 * If this value = 0, the logging system will dynamically allocate memory
 * and never truncate. However, the log functions won't be async-safe.
 *
 * Unless you're logging from within signal handlers, it's safe to set it to 0.
 */
#ifndef SentryCrashLOGGER_CBufferSize
#define SentryCrashLOGGER_CBufferSize 1024
#endif

/** Where console logs will be written */
static char g_logFilename[1024];

/** Write a formatted string to the log.
 *
 * @param fmt The format string, followed by its arguments.
 */
static void writeFmtToLog(const char* fmt, ...);

/** Write a formatted string to the log using a vararg list.
 *
 * @param fmt The format string.
 *
 * @param args The variable arguments.
 */
static void writeFmtArgsToLog(const char* fmt, va_list args);

/** Flush the log stream.
 */
static void flushLog(void);


static inline const char* lastPathEntry(const char* const path)
{
    const char* lastFile = strrchr(path, '/');
    return lastFile == 0 ? path : lastFile + 1;
}

static inline void writeFmtToLog(const char* fmt, ...)
{
    va_list args;
    va_start(args,fmt);
    writeFmtArgsToLog(fmt, args);
    va_end(args);
}

#if SentryCrashLOGGER_CBufferSize > 0

/** The file descriptor where log entries get written. */
static int g_fd = -1;

static char g_linebuffer[SentryCrashLOGGER_CBufferSize+1];
static int g_linebufsize = 0;

/** Reset the buffer position to zero
*/
static inline void resetBuffer()
{
	g_linebufsize = 0;
}

/** Writes the buffer to the log in one atomic operation, a single call to write. To avoid
 * torn writes and/or other libraries or the OS itself interleaving their logs with ours.
 */
static void flushLog(void)
{
    if(g_fd >= 0)
    {
        int bytesToWrite = g_linebufsize;
        const char* pos = g_linebuffer;
        while(bytesToWrite > 0)
        {
            int bytesWritten = (int)write(g_fd, pos, (unsigned)bytesToWrite);
            unlikely_if(bytesWritten == -1)
            {
                break;
            }
            bytesToWrite -= bytesWritten;
            pos += bytesWritten;
        }
    }
    write(STDOUT_FILENO, g_linebuffer, g_linebufsize);
    resetBuffer();
}


#define Min(a,b) ({ __auto_type _a = (a); __auto_type _b = (b); _a < _b ? _a : _b; })

static void writeToLog(const char* const str)
{
	char *pos = &g_linebuffer[g_linebufsize];
	const int last = SentryCrashLOGGER_CBufferSize;
	int remaining = last - g_linebufsize;
	g_linebufsize += Min(strlcpy(pos, str, remaining), remaining);
	
	// Make sure a newline exists on lines that overflow.
	if (g_linebufsize >= last) {
		if (g_linebuffer[last-1] != '\n') {
			g_linebuffer[last-1] = '\n';
			g_linebuffer[last] = '\0';
		}
	}
}

static void writeFmtArgsToLog(const char* fmt, va_list args)
{
    unlikely_if(fmt == NULL)
    {
        writeToLog("(null)");
    }
    else
    {
        char buffer[SentryCrashLOGGER_CBufferSize];
        vsnprintf(buffer, sizeof(buffer), fmt, args);
        writeToLog(buffer);
    }
}

static void setLogFD(int fd)
{
	if (g_fd >= 0)
	{
        close(g_fd);
		g_fd = -1;
	}
	// Don't allow pointing to stdout etc., stdout was intended to always be written as indicated by various code smells
    if(fd != STDOUT_FILENO && fd != STDERR_FILENO && fd != STDIN_FILENO)
    {
		g_fd = fd;
    }
}

bool sentrycrashlog_setLogFilename(const char* filename, bool overwrite)
{
    static int fd = -1;
    if(filename != NULL)
    {
        int openMask = O_WRONLY | O_CREAT;
        if(overwrite)
        {
            openMask |= O_TRUNC;
        }
        fd = open(filename, openMask, 0644);
        unlikely_if(fd < 0)
        {
            writeFmtToLog("SentryCrashLogger: Could not open %s: %s\n", filename, strerror(errno));
			flushLog();
            return false;
        }
        if(filename != g_logFilename)
        {
            strncpy(g_logFilename, filename, sizeof(g_logFilename));
        }
    }

    setLogFD(fd);
    return true;
}

#else // if SentryCrashLogger_CBufferSize <= 0

static FILE* g_file = NULL;

static void setLogFD(FILE* file)
{
    if (g_file != NULL)
    {
        fclose(g_file);
        g_file = NULL;
	}
	// Don't allow pointing to stdout etc.
    if (file != stdout && file != stderr && file != stdin)
    {
		g_file = file;
    }
}

static void writeToLog(const char* const str)
{
    if(g_file != NULL)
    {
        fprintf(g_file, "%s", str);
    }
    fprintf(stdout, "%s", str);
}

static void writeFmtArgsToLog(const char* fmt, va_list args)
{
    if(fmt == NULL)
    {
        writeToLog("(null)");
    }
    else
    {
		// if printing to both streams, copy the args. va_copy is very efficient
		if(g_file != NULL)
		{
			va_list cpyargs;
			va_copy(cpyargs, args);
			vfprintf(g_file, fmt, args);
			vfprintf(stdout, fmt, cpyargs);
		}
		else
		{
			vfprintf(stdout, fmt, args);
		}
    }
}

static void flushLog(void)
{
	if(g_file != NULL)
	{
	    fflush(g_file);
	}
	fflush(stdout);
}

bool sentrycrashlog_setLogFilename(const char* filename, bool overwrite)
{
    static FILE* file = NULL;
    FILE* oldFile = file;
    if(filename != NULL)
    {
        file = fopen(filename, overwrite ? "wb" : "ab");
        unlikely_if(file == NULL) {
            writeFmtToLog("SentryCrashLogger: Could not open %s: %s\n", filename, strerror(errno));
			flushLog();
            return false;
        }
    }
    if(filename != g_logFilename)
    {
        strncpy(g_logFilename, filename, sizeof(g_logFilename));
    }

    if(oldFile != NULL)
    {
        fclose(oldFile);
    }

    setLogFD(file);
    return true;
}

#endif

bool sentrycrashlog_clearLogFile()
{
    return sentrycrashlog_setLogFilename(g_logFilename, true);
}


// ===========================================================================
#pragma mark - C -
// ===========================================================================

void i_sentrycrashlog_logCBasic(const char* const fmt, ...)
{
    va_list args;
    va_start(args,fmt);
    writeFmtArgsToLog(fmt, args);
    va_end(args);
    writeToLog("\n");
    flushLog();
}

void i_sentrycrashlog_logC(const char* const level,
                  const char* const file,
                  const int line,
                  const char* const function,
                  const char* const fmt, ...)
{
    writeFmtToLog("%s: %s (%u): %s: ", level, lastPathEntry(file), line, function);
    va_list args;
    va_start(args,fmt);
    writeFmtArgsToLog(fmt, args);
    va_end(args);
    writeToLog("\n");
    flushLog();
}


// ===========================================================================
#pragma mark - Objective-C -
// ===========================================================================

#if SentryCrashCRASH_HAS_OBJC
#include <CoreFoundation/CoreFoundation.h>

void i_sentrycrashlog_logObjCBasic(CFStringRef fmt, ...)
{
    if(fmt == NULL)
    {
        writeToLog("(null)");
        flushLog();
        return;
    }

    va_list args;
    va_start(args,fmt);
    CFStringRef entry = CFStringCreateWithFormatAndArguments(NULL, NULL, fmt, args);
    va_end(args);

    int bufferLength = (int)CFStringGetLength(entry) * 4 + 1;
    char* stringBuffer = malloc((unsigned)bufferLength);
    if(CFStringGetCString(entry, stringBuffer, (CFIndex)bufferLength, kCFStringEncodingUTF8))
    {
        writeToLog(stringBuffer);
        writeToLog("\n");
    }
    else
    {
        writeToLog("Could not convert log string to UTF-8. No logging performed.\n");
    }
    flushLog();

    free(stringBuffer);
    CFRelease(entry);
}

void i_sentrycrashlog_logObjC(const char* const level,
                     const char* const file,
                     const int line,
                     const char* const function,
                     CFStringRef fmt, ...)
{
    CFStringRef logFmt = NULL;
    if(fmt == NULL)
    {
        logFmt = CFStringCreateWithCString(NULL, "%s: %s (%u): %s: (null)", kCFStringEncodingUTF8);
        i_sentrycrashlog_logObjCBasic(logFmt, level, lastPathEntry(file), line, function);
    }
    else
    {
        va_list args;
        va_start(args,fmt);
        CFStringRef entry = CFStringCreateWithFormatAndArguments(NULL, NULL, fmt, args);
        va_end(args);

        logFmt = CFStringCreateWithCString(NULL, "%s: %s (%u): %s: %@", kCFStringEncodingUTF8);
        i_sentrycrashlog_logObjCBasic(logFmt, level, lastPathEntry(file), line, function, entry);

        CFRelease(entry);
    }
    CFRelease(logFmt);
}
#endif // SentryCrashCRASH_HAS_OBJC
