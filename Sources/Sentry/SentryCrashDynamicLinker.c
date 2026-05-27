// Compatibility wrapper — adapts Sentry's SentryCrashDynamicLinker API to upstream KSCrash.

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

const uint8_t *
sentrycrashdl_imageUUID(const char *const imageName, bool exactMatch)
{
    // Not implemented — not used by remaining Sentry code paths.
    (void)imageName;
    (void)exactMatch;
    return NULL;
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
