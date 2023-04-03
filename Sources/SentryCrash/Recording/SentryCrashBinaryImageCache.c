#include "SentryCrashBinaryImageCache.h"
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <mach-o/dyld.h>

static SentryCrashBinaryImage * binaryImagesBuffer = NULL;
static uint binaryImagesBufferLength;
static int binaryImagesAmount;

static void increaseBufferSize(void) {
    uint oldLength = binaryImagesBufferLength;
    uint newLength = oldLength * 2;

    SentryCrashBinaryImage * newBuffer = malloc(sizeof(SentryCrashBinaryImage) * newLength);
    memcpy(newBuffer, binaryImagesBuffer, sizeof(SentryCrashBinaryImage) * oldLength);
    free(binaryImagesBuffer);

    binaryImagesBuffer = newBuffer;
    binaryImagesBufferLength = newLength;
}

static void
binaryImagesAdded(const struct mach_header *header, intptr_t slide) {
    if (binaryImagesBuffer == NULL) {
        return;
    }

    binaryImagesAmount = sentrycrashdl_imageCount();

    if (binaryImagesBuffer != NULL) {
        free(binaryImagesBuffer);
    }

    binaryImagesBuffer = malloc(sizeof(SentryCrashBinaryImage) * binaryImagesAmount);

    for (int i = 0; i<binaryImagesAmount; i++) {
        SentryCrashBinaryImage image = { 0 };
        if (!sentrycrashdl_getBinaryImage(i, &image)) {
            continue;
        }
        binaryImagesBuffer[i] = image;
    }
}

int sentrycrashbic_imageCount(void) {
    return binaryImagesAmount;
}

SentryCrashBinaryImage * sentrycrashbic_getBinaryImageBuffer(int index) {
    return &binaryImagesBuffer[index];
}

void sentrycrashbic_startCache(void) {
    binaryImagesBufferSize = 20;
    binaryImagesBuffer = malloc(sizeof(SentryCrashBinaryImage) * binaryImagesBufferSize);
    binaryImagesAmount = 0;
    _dyld_register_func_for_add_image(&binaryImagesAdded);
}

void sentrycrashbic_stopCache(void) {
    free(binaryImagesBuffer);
    binaryImagesBuffer = NULL;
    binaryImagesAmount = 0;
    _dyld_register_func_for_remove_image(&binaryImagesAdded);
}
