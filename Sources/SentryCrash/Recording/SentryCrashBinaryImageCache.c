#include "SentryCrashBinaryImageCache.h"
#include "SentryCrashDynamicLinker.h"
#include <mach-o/dyld.h>
#include <mach-o/dyld_images.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

typedef void (*SentryRegisterImageCallback)(const struct mach_header *mh, intptr_t vmaddr_slide);
typedef void (*SentryRegisterFunction)(SentryRegisterImageCallback function);

static SentryRegisterFunction _sentry_register_func_for_add_image
    = &_dyld_register_func_for_add_image;
static SentryRegisterFunction _sentry_register_func_for_remove_image
    = &_dyld_register_func_for_remove_image;

static void (*SentryWillAddImageCallback)(void) = NULL;

void
sentry_setRegisterFuncForAddImage(SentryRegisterFunction addFunction)
{
    _sentry_register_func_for_add_image = addFunction;
}

void
sentry_setRegisterFuncForRemoveImage(SentryRegisterFunction removeFunction)
{
    _sentry_register_func_for_remove_image = removeFunction;
}

void
sentry_setFuncForBeforeAdd(void (*callback)(void))
{
    SentryWillAddImageCallback = callback;
}

void
sentry_resetFuncForAddRemoveImage(void)
{
    _sentry_register_func_for_add_image = &_dyld_register_func_for_add_image;
    _sentry_register_func_for_remove_image = &_dyld_register_func_for_remove_image;
}

#    define sentry_dyld_register_func_for_add_image(CALLBACK)                                      \
        _sentry_register_func_for_add_image(CALLBACK);
#    define sentry_dyld_register_func_for_remove_image(CALLBACK)                                   \
        _sentry_register_func_for_remove_image(CALLBACK);
#    define _will_add_image()                                                                      \
        if (SentryWillAddImageCallback)                                                            \
            SentryWillAddImageCallback();
#else
#    define sentry_dyld_register_func_for_add_image(CALLBACK)                                      \
        _dyld_register_func_for_add_image(CALLBACK)
#    define sentry_dyld_register_func_for_remove_image(CALLBACK)                                   \
        _dyld_register_func_for_remove_image(CALLBACK)
#    define _will_add_image()
#endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

typedef struct SentryCrashBinaryImageNode {
    SentryCrashBinaryImage image;
    bool available;
    struct SentryCrashBinaryImageNode *next;
} SentryCrashBinaryImageNode;

static pthread_mutex_t binaryImagesMutex = PTHREAD_MUTEX_INITIALIZER;
static SentryCrashBinaryImageNode rootNode = { 0 };
static _Atomic(SentryCrashBinaryImageNode *) tailNode = NULL;
static _Atomic(sentrycrashbic_cacheChangeCallback) imageAddedCallback = NULL;
static _Atomic(sentrycrashbic_cacheChangeCallback) imageRemovedCallback = NULL;

static void
binaryImageAdded(const struct mach_header *header, intptr_t slide)
{
    // Quick check without the mutex — tailNode is atomic so this is safe.
    // If cache was stopped (NULL), skip all work including dladdr.
    if (atomic_load_explicit(&tailNode, memory_order_acquire) == NULL) {
        return;
    }
    Dl_info info;
    if (!dladdr(header, &info) || info.dli_fname == NULL) {
        return;
    }

    SentryCrashBinaryImage binaryImage = { 0 };
    if (!sentrycrashdl_getBinaryImageForHeader(
            (const void *)header, info.dli_fname, &binaryImage, false)) {
        return;
    }

    SentryCrashBinaryImageNode *newNode = malloc(sizeof(SentryCrashBinaryImageNode));
    newNode->available = true;
    newNode->image = binaryImage;
    newNode->next = NULL;
    _will_add_image();
    pthread_mutex_lock(&binaryImagesMutex);
    // Recheck tailNode under mutex — it could have been set to NULL by
    // stopCache() between our atomic check above and this point.
    SentryCrashBinaryImageNode *currentTail = atomic_load_explicit(&tailNode, memory_order_relaxed);
    if (currentTail != NULL) {
        currentTail->next = newNode;
        atomic_store_explicit(&tailNode, newNode, memory_order_release);
    } else {
        free(newNode);
        newNode = NULL;
    }
    pthread_mutex_unlock(&binaryImagesMutex);
    if (newNode) {
        sentrycrashbic_cacheChangeCallback addCb
            = atomic_load_explicit(&imageAddedCallback, memory_order_acquire);
        if (addCb) {
            addCb(&newNode->image);
        }
    }
}

static void
binaryImageRemoved(const struct mach_header *header, intptr_t slide)
{
    SentryCrashBinaryImageNode *nextNode = &rootNode;

    while (nextNode != NULL) {
        if (nextNode->image.address == (uint64_t)header) {
            nextNode->available = false;
            sentrycrashbic_cacheChangeCallback rmCb
                = atomic_load_explicit(&imageRemovedCallback, memory_order_acquire);
            if (rmCb) {
                rmCb(&nextNode->image);
            }
            break;
        }
        nextNode = nextNode->next;
    }
}

void
sentrycrashbic_iterateOverImages(sentrycrashbic_imageIteratorCallback callback, void *context)
{
    /**
     We can't use locks here because this is meant to be used during crashes,
     where we can't use async unsafe functions. In order to avoid potential problems,
     we choose an approach that doesn't remove nodes from the list.
    */
    SentryCrashBinaryImageNode *nextNode = &rootNode;

    // If tailNode is null it means the cache was stopped, therefore we end the iteration.
    // This will minimize any race condition effect without the need for locks.
    while (nextNode != NULL && atomic_load_explicit(&tailNode, memory_order_acquire) != NULL) {
        if (nextNode->available) {
            callback(&nextNode->image, context);
        }
        nextNode = nextNode->next;
    }
}

/** Check if dyld should be added to the binary image cache.
 *
 * Since Apple no longer includes dyld in the images listed by _dyld_image_count and related
 * functions, we need to check if dyld is already present in our cache before adding it.
 *
 * @return true if dyld is not found in the loaded images and should be added to the cache,
 *         false if dyld is already present in the loaded images.
 */
bool
sentrycrashbic_shouldAddDyld(void)
{
    // dyld is different from libdyld.dylib; the latter contains the public API
    // (like dlopen, dlsym, dlclose) while the former is the actual dynamic
    // linker executable that handles runtime library loading and symbol resolution
    return sentrycrashdl_imageNamed("/usr/lib/dyld", false) == UINT32_MAX;
}

// Since Apple no longer includes dyld in the images listed `_dyld_image_count` and related
// functions We manually include it to our cache.
SentryCrashBinaryImageNode *
sentrycrashbic_getDyldNode(void)
{
    const struct mach_header *header = sentryDyldHeader;

    SentryCrashBinaryImage binaryImage = { 0 };
    if (!sentrycrashdl_getBinaryImageForHeader((const void *)header, "dyld", &binaryImage, false)) {
        return NULL;
    }

    SentryCrashBinaryImageNode *newNode = malloc(sizeof(SentryCrashBinaryImageNode));
    newNode->available = true;
    newNode->image = binaryImage;
    newNode->next = NULL;

    return newNode;
}

void
sentrycrashbic_startCache(void)
{
    pthread_mutex_lock(&binaryImagesMutex);
    if (atomic_load_explicit(&tailNode, memory_order_relaxed) != NULL) {
        // Already initialized
        pthread_mutex_unlock(&binaryImagesMutex);
        return;
    }

    if (sentrycrashbic_shouldAddDyld()) {
        sentrycrashdl_initialize();
        SentryCrashBinaryImageNode *dyldNode = sentrycrashbic_getDyldNode();
        atomic_store_explicit(&tailNode, dyldNode, memory_order_release);
        rootNode.next = dyldNode;
    } else {
        atomic_store_explicit(&tailNode, &rootNode, memory_order_release);
        rootNode.next = NULL;
    }
    pthread_mutex_unlock(&binaryImagesMutex);

    // During a call to _dyld_register_func_for_add_image() the callback func is called for every
    // existing image
    sentry_dyld_register_func_for_add_image(&binaryImageAdded);
    sentry_dyld_register_func_for_remove_image(&binaryImageRemoved);
}

void
sentrycrashbic_stopCache(void)
{
    pthread_mutex_lock(&binaryImagesMutex);
    if (atomic_load_explicit(&tailNode, memory_order_relaxed) == NULL) {
        pthread_mutex_unlock(&binaryImagesMutex);
        return;
    }

    SentryCrashBinaryImageNode *node = rootNode.next;
    rootNode.next = NULL;
    atomic_store_explicit(&tailNode, NULL, memory_order_release);

    while (node != NULL) {
        SentryCrashBinaryImageNode *nextNode = node->next;
        free(node);
        node = nextNode;
    }

    pthread_mutex_unlock(&binaryImagesMutex);
}

void
sentrycrashbic_registerAddedCallback(sentrycrashbic_cacheChangeCallback callback)
{
    atomic_store_explicit(&imageAddedCallback, callback, memory_order_release);
    if (callback) {
        // Snapshot the current tail under the mutex, then iterate outside it.
        // This avoids holding the mutex for the entire iteration, which would
        // block any concurrent binaryImageAdded() calls (e.g. from dlopen on
        // another thread during SDK startup). Nodes are never freed during
        // normal operation, so the snapshot pointer remains valid.
        pthread_mutex_lock(&binaryImagesMutex);
        SentryCrashBinaryImageNode *snapshotTail
            = atomic_load_explicit(&tailNode, memory_order_acquire);
        pthread_mutex_unlock(&binaryImagesMutex);

        if (snapshotTail != NULL) {
            SentryCrashBinaryImageNode *node = &rootNode;
            while (node != NULL) {
                if (node->available) {
                    callback(&node->image);
                }
                if (node == snapshotTail) {
                    break;
                }
                node = node->next;
            }
        }
    }
}

void
sentrycrashbic_registerRemovedCallback(sentrycrashbic_cacheChangeCallback callback)
{
    atomic_store_explicit(&imageRemovedCallback, callback, memory_order_release);
}
