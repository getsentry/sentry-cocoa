// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashDynamicLinker.c
//
//  Created by Karl Stenerud on 2013-10-02.
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

#include "SentryCrashDynamicLinker.h"
#include "KSDynamicLinker.h"
#include "SentryCrashUUIDConversion.h"

#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/dyld_images.h>
#include <mach/mach_init.h>
#include <mach/task.h>
#include <string.h>

const struct mach_header *sentryDyldHeader = NULL;

static struct dyld_all_image_infos *
getAllImageInfo(void)
{
    struct task_dyld_info dyld_info;
    mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
    kern_return_t kr = task_info(mach_task_self(), TASK_DYLD_INFO, (task_info_t)&dyld_info, &count);
    if (kr != KERN_SUCCESS) {
        return NULL;
    }
    return (struct dyld_all_image_infos *)dyld_info.all_image_info_addr;
}

void
sentrycrashdl_initialize(void)
{
    if (sentryDyldHeader == NULL) {
        struct dyld_all_image_infos *infos = getAllImageInfo();
        if (infos && infos->dyldImageLoadAddress) {
            sentryDyldHeader = (const struct mach_header *)infos->dyldImageLoadAddress;
        }
    }
}

uint32_t
sentrycrashdl_imageNamed(const char *const imageName, bool exactMatch)
{
    if (imageName == NULL) {
        return UINT32_MAX;
    }
    const uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name == NULL)
            continue;
        if (exactMatch) {
            if (strcmp(name, imageName) == 0)
                return i;
        } else {
            if (strstr(name, imageName) != NULL)
                return i;
        }
    }
    return UINT32_MAX;
}

bool
sentrycrashdl_getBinaryImageForHeader(const void *const header_ptr, const char *const image_name,
    SentryCrashBinaryImage *buffer, bool isCrash)
{
    KSBinaryImage ksImage;
    if (!ksdl_binaryImageForHeader(header_ptr, image_name, &ksImage)) {
        return false;
    }
    buffer->address = (uintptr_t)ksImage.address;
    buffer->vmAddress = (uint64_t)ksImage.vmAddress;
    buffer->size = (uint64_t)ksImage.size;
    buffer->name = ksImage.name;
    buffer->uuid = ksImage.uuid;
    buffer->cpuType = (int)ksImage.cpuType;
    buffer->cpuSubType = (int)ksImage.cpuSubType;
    buffer->crashInfoMessage = isCrash ? ksImage.crashInfoMessage : NULL;
    buffer->crashInfoMessage2 = isCrash ? ksImage.crashInfoMessage2 : NULL;
    return true;
}

void
sentrycrashdl_clearDyld(void)
{
    sentryDyldHeader = NULL;
}

void
sentrycrashdl_getCrashInfo(uint64_t address, SentryCrashBinaryImage *buffer)
{
    // Not used by remaining Sentry code paths after migration.
    (void)address;
    (void)buffer;
}
