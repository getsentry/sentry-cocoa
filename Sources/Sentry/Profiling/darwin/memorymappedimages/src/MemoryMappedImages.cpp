// Copyright (c) Specto Inc. All rights reserved.

#include "MemoryMappedImages.h"

#include "spectoproto/memorymappedimages/memorymappedimages_generated.pb.h"

#include <cassert>
#include <mach-o/arch.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <uuid/uuid.h>

#if defined(__LP64__) && __LP64__
#define LC_SEGMENT_ARCH LC_SEGMENT_64
using specto_mach_header = mach_header_64;
using specto_mach_segment_command = segment_command_64;
#else
#define LC_SEGMENT_ARCH LC_SEGMENT
typedef mach_header specto_mach_header;
typedef segment_command specto_mach_segment_command;
#endif

namespace specto::darwin {
namespace {

bool getMappedImage(proto::MemoryMappedImage *image, uint32_t index) {
    const auto header = reinterpret_cast<const specto_mach_header *>(_dyld_get_image_header(index));
    if (header == nullptr) {
        return false;
    }

#ifdef __LP64__
    assert(header->magic == MH_MAGIC_64);
    if (header->magic != MH_MAGIC_64) {
        return false;
    }
#else
    assert(header->magic == MH_MAGIC);
    if (header->magic != MH_MAGIC) {
        return false;
    }
#endif

    const auto archInfo = NXGetArchInfoFromCpuType(header->cputype, header->cpusubtype);
    if (archInfo == nullptr) {
        return false;
    }
    image->set_architecture(archInfo->name);

    const auto slide = _dyld_get_image_vmaddr_slide(index);
    const auto name = _dyld_get_image_name(index);
    auto cmd = reinterpret_cast<const struct load_command *>(header + 1);

    bool foundTextSegment = false;
    bool foundUUIDCommand = false;
    for (uint32_t i = 0; cmd && (i < header->ncmds); i++) {
        if (cmd->cmd == LC_SEGMENT_ARCH) {
            const auto seg = reinterpret_cast<const specto_mach_segment_command *>(cmd);

            if (!strcmp(seg->segname, "__TEXT")) {
                image->set_address(seg->vmaddr + slide);
                image->set_size_bytes(seg->vmsize);
                image->set_image_file_path(name);
                foundTextSegment = true;
            }
        } else if (cmd->cmd == LC_UUID) {
            const auto uuidCmd = reinterpret_cast<const uuid_command *>(cmd);
            uuid_string_t uuidString;
            uuid_unparse_lower(uuidCmd->uuid, uuidString);
            image->set_uuid(uuidString);
            foundUUIDCommand = true;
        }
        if (foundTextSegment && foundUUIDCommand) {
            break;
        }
        cmd = reinterpret_cast<struct load_command *>((char *)cmd + cmd->cmdsize);
    }
    return (foundTextSegment && foundUUIDCommand);
}

} // namespace

proto::MemoryMappedImages getMemoryMappedImages() {
    proto::MemoryMappedImages images;
    const auto imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; ++i) {
        const auto addedIndex = images.images_size();
        if (!getMappedImage(images.add_images(), i)) {
            images.mutable_images()->DeleteSubrange(addedIndex, 1);
        }
    }
    return images;
}

} // namespace specto::darwin
