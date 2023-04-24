#include "SentryCrashBinaryImageCache.h"
#include "SentryCrashDynamicLinker.h"
#include <mach-o/dyld.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define CACHE_SIZE_INCREMENT 100
static SentryCrashBinaryImage *binaryImagesBuffer = NULL;
static uint binaryImagesBufferLength;
static int binaryImagesAmount;
static pthread_mutex_t binaryImagesMutex = PTHREAD_MUTEX_INITIALIZER;

static void
increaseBufferSize(void)
{
    uint oldLength = binaryImagesBufferLength;
    uint newLength = oldLength + CACHE_SIZE_INCREMENT;

    SentryCrashBinaryImage *newBuffer = malloc(sizeof(SentryCrashBinaryImage) * newLength);
    memcpy(newBuffer, binaryImagesBuffer, sizeof(SentryCrashBinaryImage) * oldLength);
    free(binaryImagesBuffer);

    binaryImagesBuffer = newBuffer;
    binaryImagesBufferLength = newLength;
}

static void
binaryImageAdded(const struct mach_header *header, intptr_t slide)
{
    if (binaryImagesBuffer == NULL) {
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

    pthread_mutex_lock(&binaryImagesMutex);
    if (binaryImagesAmount >= binaryImagesBufferLength) {
        increaseBufferSize();
    }
    binaryImagesBuffer[binaryImagesAmount++] = binaryImage;
    pthread_mutex_unlock(&binaryImagesMutex);
}

static void
binaryImageRemoved(const struct mach_header *header, intptr_t slide)
{
    pthread_mutex_lock(&binaryImagesMutex);
    int index = -1;
    for (int i = 0; i < binaryImagesAmount; i++) {
        if (binaryImagesBuffer[i].address == (uint64_t)header) {
            index = i;
            break;
        }
    }

    if (index < 0 || index >= binaryImagesAmount) {
        pthread_mutex_unlock(&binaryImagesMutex);
        return;
    }

    size_t itemSize = sizeof(SentryCrashBinaryImage);

    int amountToMove = binaryImagesAmount - index + 1;
    size_t sizeToMove = amountToMove * itemSize;
    void *startPosition = binaryImagesBuffer + ((index + 1) * itemSize);
    void *moveTo = startPosition - itemSize;

    memcpy(moveTo, startPosition, sizeToMove);
    binaryImagesAmount--;

    pthread_mutex_unlock(&binaryImagesMutex);
}

int
sentrycrashbic_imageCount(void)
{
    return binaryImagesAmount;
}

SentryCrashBinaryImage *
sentrycrashbic_getCachedBinaryImage(int index)
{
    //This function is not thread safe, because this is meant to be used during crash signal handling.
    if (index >= binaryImagesAmount) {
        return NULL;
    }
    return &binaryImagesBuffer[index];
}



void
sentrycrashbic_startCache(void)
{
    pthread_mutex_lock(&binaryImagesMutex);
    if (binaryImagesBuffer) {
        free(binaryImagesBuffer);
    }
    binaryImagesBufferLength = CACHE_SIZE_INCREMENT;
    binaryImagesBuffer = malloc(sizeof(SentryCrashBinaryImage) * binaryImagesBufferLength);
    binaryImagesAmount = 0;
    pthread_mutex_unlock(&binaryImagesMutex);

    //During a call to _dyld_register_func_for_add_image() the callback func is called for every existing image
    _dyld_register_func_for_add_image(&binaryImageAdded);
    _dyld_register_func_for_remove_image(&binaryImageRemoved);
}

void
sentrycrashbic_stopCache(void)
{
    pthread_mutex_lock(&binaryImagesMutex);
    if (binaryImagesBuffer == NULL) {
        pthread_mutex_unlock(&binaryImagesMutex);
        return;
    }
    free(binaryImagesBuffer);
    binaryImagesBuffer = NULL;
    binaryImagesAmount = 0;
    binaryImagesBufferLength = 0;
    pthread_mutex_unlock(&binaryImagesMutex);
}
