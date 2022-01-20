// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#ifndef __APPLE__
#error Non-Apple platforms are not supported!
#endif

namespace specto {
namespace proto {
class MemoryMappedImages;
}
namespace darwin {
/**
 * @return A vector with the list of the mapping of dynamic libraries.
 */
proto::MemoryMappedImages getMemoryMappedImages();

} // namespace darwin
} // namespace specto
