// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryAttachmentCallback.h
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
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

/** Sentry-custom attachment callback API layered on top of the vendored SentryCrash sources.
 * These functions are implemented in Sources/SentryCrash/Recording/SentryCrashC.c.
 */

#ifndef HDR_SentryAttachmentCallback_h
#define HDR_SentryAttachmentCallback_h

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * A callback invoked during a crash to save an attachment to a directory.
 *
 * @param directoryPath Path to the directory where the attachment should be saved.
 */
typedef void (*SaveAttachmentCallback)(const char *directoryPath);

/** Set the callback to invoke when saving screenshots during a crash.
 *
 * @param callback The callback to invoke, or NULL to clear.
 */
void sentrycrash_setSaveScreenshots(SaveAttachmentCallback callback);

/** Set the callback to invoke when saving view hierarchy during a crash.
 *
 * @param callback The callback to invoke, or NULL to clear.
 */
void sentrycrash_setSaveViewHierarchy(SaveAttachmentCallback callback);

bool sentrycrash_hasSaveScreenshotCallback(void);
bool sentrycrash_hasSaveViewHierarchyCallback(void);

#ifdef __cplusplus
}
#endif

#endif // HDR_SentryAttachmentCallback_h
