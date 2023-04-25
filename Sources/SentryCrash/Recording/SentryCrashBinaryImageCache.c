#include "SentryCrashBinaryImageCache.h"
#include "SentryCrashDynamicLinker.h"
#include <mach-o/dyld.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>


typedef struct SentryCrashBinaryImageNode {
    SentryCrashBinaryImage image;
    bool available;
    struct SentryCrashBinaryImageNode * next;
} SentryCrashBinaryImageNode;

static SentryCrashBinaryImageNode rootNode = { 0 };
static SentryCrashBinaryImageNode * tailNode = NULL;
static pthread_mutex_t binaryImagesMutex = PTHREAD_MUTEX_INITIALIZER;

static void
binaryImageAdded(const struct mach_header *header, intptr_t slide)
{
    pthread_mutex_lock(&binaryImagesMutex);
    if (tailNode == NULL) {
        pthread_mutex_unlock(&binaryImagesMutex);
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

    SentryCrashBinaryImageNode newNode = { 0 };
    newNode.available = true;
    newNode.image = binaryImage;

    tailNode->next = malloc(sizeof(SentryCrashBinaryImageNode));
    *tailNode->next = newNode;
    tailNode = tailNode->next;
    pthread_mutex_unlock(&binaryImagesMutex);
}

static void
binaryImageRemoved(const struct mach_header *header, intptr_t slide)
{
    SentryCrashBinaryImageNode* nextNode = &rootNode;

    while (nextNode != NULL) {
        if (nextNode->image.address == (uint64_t)header){
            nextNode->available = false;
            break;
        }
        nextNode = nextNode->next;
    }
}

void sentrycrashbic_iterateOverImages(sentrycrashbic_imageIteratorCallback callback, void * context) {
    SentryCrashBinaryImageNode* nextNode = &rootNode;

    while (nextNode != NULL) {
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
        //Already initialized
        pthread_mutex_unlock(&binaryImagesMutex);
        return;
    }
    tailNode = &rootNode;
    rootNode.next = NULL;
    pthread_mutex_unlock(&binaryImagesMutex);

    // During a call to _dyld_register_func_for_add_image() the callback func is called for every
    // existing image
    _dyld_register_func_for_add_image(&binaryImageAdded);
    _dyld_register_func_for_remove_image(&binaryImageRemoved);
}

void
sentrycrashbic_stopCache(void)
{
    pthread_mutex_lock(&binaryImagesMutex);
    if (tailNode == NULL) {
        pthread_mutex_unlock(&binaryImagesMutex);
        return;
    }

    SentryCrashBinaryImageNode* node = rootNode.next;
    rootNode.next = NULL;

    while (node != NULL) {
        SentryCrashBinaryImageNode* nextNode = node->next;
        free(node);
        node = nextNode;
    }

    pthread_mutex_unlock(&binaryImagesMutex);
}
