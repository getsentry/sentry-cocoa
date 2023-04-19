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
    pthread_mutex_lock(&binaryImagesMutex);
    uint oldLength = binaryImagesBufferLength;
    uint newLength = oldLength + CACHE_SIZE_INCREMENT;

    SentryCrashBinaryImage *newBuffer = malloc(sizeof(SentryCrashBinaryImage) * newLength);
    memcpy(newBuffer, binaryImagesBuffer, sizeof(SentryCrashBinaryImage) * oldLength);
    free(binaryImagesBuffer);

    binaryImagesBuffer = newBuffer;
    binaryImagesBufferLength = newLength;
    pthread_mutex_unlock(&binaryImagesMutex);
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

    if (binaryImagesAmount >= binaryImagesBufferLength) {
        increaseBufferSize();
    }

    binaryImagesBuffer[binaryImagesAmount++] = binaryImage;
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

    if (index >= binaryImagesAmount) {
        return;
    }

    if (index >= 0) {
        int amountToMove = binaryImagesAmount - index + 1;
        int sizeToMove = amountToMove * sizeof(SentryCrashBinaryImage);
        void * startPosition = binaryImagesBuffer + ((index + 1) * sizeof(SentryCrashBinaryImage));
        void * moveTo = startPosition - sizeof(SentryCrashBinaryImage);

        memcmp(moveTo, startPosition, sizeToMove);
        binaryImagesAmount--;
    }

    pthread_mutex_unlock(&binaryImagesMutex);
}

int
sentrycrashbic_imageCount(void)
{
    return binaryImagesAmount;
}

SentryCrashBinaryImage *
sentrycrashbic_getBinaryImageCache(int index)
{
    return &binaryImagesBuffer[index];
}

void
sentrycrashbic_startCache(void)
{
    binaryImagesBufferLength = CACHE_SIZE_INCREMENT;
    binaryImagesBuffer = malloc(sizeof(SentryCrashBinaryImage) * binaryImagesBufferLength);
    binaryImagesAmount = 0;
    _dyld_register_func_for_add_image(&binaryImageAdded);
    _dyld_register_func_for_remove_image(&binaryImageRemoved);
}

void
sentrycrashbic_stopCache(void)
{
    free(binaryImagesBuffer);
    binaryImagesBuffer = NULL;
    binaryImagesAmount = 0;
    binaryImagesBufferLength = 0;
}
