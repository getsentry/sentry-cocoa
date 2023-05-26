#include "SentryCrashBinaryImageCache.h"
#include "SentryCrashDynamicLinker.h"
#include <mach-o/dyld.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#if TEST || TESTCI

typedef void (*SentryRegisterImageCallback)(const struct mach_header *mh, intptr_t vmaddr_slide);
typedef void (*SentryRegisterFunction)(SentryRegisterImageCallback function);

static SentryRegisterFunction _sentry_register_func_for_add_image
    = &_dyld_register_func_for_add_image;
static SentryRegisterFunction _sentry_register_func_for_remove_image
    = &_dyld_register_func_for_remove_image;

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
sentry_resetFuncForAddRemoveImage(void)
{
    _sentry_register_func_for_add_image = &_dyld_register_func_for_add_image;
    _sentry_register_func_for_remove_image = &_dyld_register_func_for_remove_image;
}

#    define sentry_dyld_register_func_for_add_image(CALLBACK)                                      \
        _sentry_register_func_for_add_image(CALLBACK);
#    define sentry_dyld_register_func_for_remove_image(CALLBACK)                                   \
        _sentry_register_func_for_remove_image(CALLBACK);

#else
#    define sentry_dyld_register_func_for_add_image(CALLBACK)                                      \
        _dyld_register_func_for_add_image(CALLBACK)
#    define sentry_dyld_register_func_for_remove_image(CALLBACK)                                   \
        _dyld_register_func_for_remove_image(CALLBACK)
#endif

typedef struct SentryCrashBinaryImageNode {
    SentryCrashBinaryImage image;
    bool available;
    struct SentryCrashBinaryImageNode *next;
} SentryCrashBinaryImageNode;

static SentryCrashBinaryImageNode rootNode = { 0 };
static SentryCrashBinaryImageNode *tailNode = NULL;
static pthread_mutex_t binaryImagesMutex = PTHREAD_MUTEX_INITIALIZER;

static void
binaryImageAdded(const struct mach_header *header, intptr_t slide)
{
    if (tailNode == NULL) {
        return;
    }

    Dl_info info;
    if (!dladdr(header, &info) || info.dli_fname == NULL) {
        return;
    }

    SentryCrashBinaryImage binaryImage = { 0 };
    if (!sentrycrashdl_getBinaryImageForHeader(
            (const void *)header, info.dli_fname, &binaryImage)) {
        return;
    }

    SentryCrashBinaryImageNode *newNode = malloc(sizeof(SentryCrashBinaryImageNode));
    newNode->available = true;
    newNode->image = binaryImage;
    newNode->next = NULL;

    pthread_mutex_lock(&binaryImagesMutex);
    // Recheck tailNode as it could be null when
    // stopped from another thread.
    if (tailNode != NULL) {
        tailNode->next = newNode;
        tailNode = tailNode->next;
    } else {
        free(newNode);
    }
    pthread_mutex_unlock(&binaryImagesMutex);
}

static void
binaryImageRemoved(const struct mach_header *header, intptr_t slide)
{
    SentryCrashBinaryImageNode *nextNode = &rootNode;

    while (nextNode != NULL) {
        if (nextNode->image.address == (uint64_t)header) {
            nextNode->available = false;
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
    while (nextNode != NULL && tailNode != NULL) {
        if (nextNode->available) {
            callback(&nextNode->image, context);
        }
        nextNode = nextNode->next;
    }
}

void
sentrycrashbic_startCache(void)
{
    pthread_mutex_lock(&binaryImagesMutex);
    if (tailNode != NULL) {
        // Already initialized
        pthread_mutex_unlock(&binaryImagesMutex);
        return;
    }
    tailNode = &rootNode;
    rootNode.next = NULL;
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
    if (tailNode == NULL) {
        pthread_mutex_unlock(&binaryImagesMutex);
        return;
    }

    SentryCrashBinaryImageNode *node = rootNode.next;
    rootNode.next = NULL;
    tailNode = NULL;

    while (node != NULL) {
        SentryCrashBinaryImageNode *nextNode = node->next;
        free(node);
        node = nextNode;
    }

    pthread_mutex_unlock(&binaryImagesMutex);
}
