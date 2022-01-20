// Copyright (c) Specto Inc. All rights reserved.

// Adapted from Firebase Crashlytics; the original license content follows, in
// compliance with that license:

// Copyright 2019 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "Mach.h"

#include "cpp/debugger/src/Debugger.h"
#include "cpp/io/src/IO.h"
#include "cpp/log/src/Log.h"
#include "cpp/memory/src/Memory.h"
#include "cpp/signals/src/Handling.h"
#include "cpp/util/src/ArraySize.h"

#include <atomic>
#include <cstdint>
#include <cstdlib>
#include <pthread.h>

namespace sig = specto::signal;

namespace specto::darwin::exception {

namespace {

#pragma mark - Definitions

struct OriginalPorts {
    mach_msg_type_number_t count;
    exception_mask_t masks[EXC_TYPES_COUNT];
    exception_handler_t ports[EXC_TYPES_COUNT];
    exception_behavior_t behaviors[EXC_TYPES_COUNT];
    thread_state_flavor_t flavors[EXC_TYPES_COUNT];
};

struct ReadOnlyContext {
    void* machStack;
    mach_port_t port;
    pthread_t pthread;
    thread_t thread;
    const char* markerFilePaths[util::countof(exceptions_)];

    exception_mask_t mask;
    OriginalPorts originalPorts;
    const char* logPath;
    spdlog::level::level_enum logLevel;
};

struct ReadWriteContext {
    int logFd;
};

struct MachExceptionContext {
    ReadOnlyContext* readonly;
    ReadWriteContext* writable;
    memory::AllocatorRef allocator;
};

MachExceptionContext _machExceptionContext;

static_assert(ATOMIC_BOOL_LOCK_FREE == 2, "Mach exception toggling requires async-safe state.");
std::atomic_bool _enabled {false};

#pragma pack(push, 4)
typedef struct {
    mach_msg_header_t head;
    /* start of the kernel processed data */
    mach_msg_body_t msgh_body;
    mach_msg_port_descriptor_t thread;
    mach_msg_port_descriptor_t task;
    /* end of the kernel processed data */
    NDR_record_t NDR;
    exception_type_t exception;
    mach_msg_type_number_t codeCnt;
    mach_exception_data_type_t code[EXCEPTION_CODE_MAX];
    mach_msg_trailer_t trailer;
} Message;

typedef struct {
    mach_msg_header_t head;
    NDR_record_t NDR;
    kern_return_t retCode;
} Reply;
#pragma pack(pop)

/** Must be at least PTHREAD_STACK_MIN size. */
constexpr auto machExceptionHandlerStackSize_ = 256 * 1024;

constexpr auto minimumReadwriteSize_ = machExceptionHandlerStackSize_ + sizeof(ReadWriteContext);

// We need enough space here for the context, plus storage for strings.
constexpr auto minimumReadableSize_ = sizeof(ReadOnlyContext) + 4096 * 4;

#pragma mark - Logging

#if !defined(NDEBUG)
#define SPECTO_EXCEPTION_SAFE_LOG_DEBUG(__FORMAT__, ...) \
    exceptionSafeLog(                                    \
      spdlog::level::debug, "[debug] [%s:%d] " __FORMAT__ "\n", __FILE__, __LINE__, ##__VA_ARGS__)
#define SPECTO_EXCEPTION_SAFE_LOG_INFO(__FORMAT__, ...) \
    exceptionSafeLog(                                   \
      spdlog::level::info, "[info] [%s:%d] " __FORMAT__ "\n", __FILE__, __LINE__, ##__VA_ARGS__)
#else
#define SPECTO_EXCEPTION_SAFE_LOG_DEBUG(__FORMAT__, ...)
#define SPECTO_EXCEPTION_SAFE_LOG_INFO(__FORMAT__, ...)
#endif
#define SPECTO_EXCEPTION_SAFE_LOG_WARN(__FORMAT__, ...) \
    exceptionSafeLog(                                   \
      spdlog::level::warn, "[warn] [%s:%d] " __FORMAT__ "\n", __FILE__, __LINE__, ##__VA_ARGS__)
#define SPECTO_EXCEPTION_SAFE_LOG_ERROR(__FORMAT__, ...) \
    exceptionSafeLog(                                    \
      spdlog::level::err, "[error] [%s:%d] " __FORMAT__ "\n", __FILE__, __LINE__, ##__VA_ARGS__)

/**
 * @note There are lots of things that can fail here, hence all the early returns, but we can never
 * really know if/how it happens in the wild, since we can't log anything!
 * @warning Don't call directly; use one of the SPECTO_EXCEPTION_SAFE_LOG_ macros.
 */
void exceptionSafeLog(spdlog::level::level_enum level, const char* format, ...) {
    if (!_machExceptionContext.readonly || !_machExceptionContext.writable) {
        return;
    }

    const auto path = _machExceptionContext.readonly->logPath;
    if (!SPECTO_IS_VALID_POINTER(path)) {
        return;
    }

    if (_machExceptionContext.readonly->logLevel > level) {
        return;
    }

    if (_machExceptionContext.writable->logFd == -1) {
        _machExceptionContext.writable->logFd = fs::fileDescriptorForPath(path, true);
    }

    const auto fd = _machExceptionContext.writable->logFd;
    if (fd < 0) {
        return;
    }

    va_list args;
    va_start(args, format);
    io::async_safe::safeWrite(fd, format, args);
    va_end(args);
}

#pragma mark - Register/Unregister

exception_mask_t exceptionMask() {
    exception_mask_t mask;

    // comment below from original Firebase Crashlytics source: (armcknight 6/11/20)
    // EXC_BAD_ACCESS
    // EXC_BAD_INSTRUCTION
    // EXC_ARITHMETIC
    // EXC_EMULATION - non-failure
    // EXC_SOFTWARE - non-failure
    // EXC_BREAKPOINT - trap instructions, from the debugger and code. Needs special treatment.
    // EXC_SYSCALL - non-failure
    // EXC_MACH_SYSCALL - non-failure
    // EXC_RPC_ALERT - non-failure
    // EXC_CRASH - see below
    // EXC_RESOURCE - non-failure, happens when a process exceeds a resource limit
    // EXC_GUARD - see below
    //
    // EXC_CRASH is a special kind of exception.  It is handled by launchd, and treated special by
    // the kernel.  Seems that we cannot safely catch it - our handler will never be called.  This
    // is a confirmed kernel bug.  Lacking access to EXC_CRASH means we must use signal handlers to
    // cover all types of crashes.
    // EXC_GUARD is relatively new, and isn't available on all OS versions. You have to be careful,
    // becuase you cannot succesfully register hanlders if there are any unrecognized masks. We've
    // dropped support for old OS versions that didn't have EXC_GUARD (iOS 5 and below, macOS 10.6
    // and below) so we always add it now

    mask = EXC_MASK_BAD_ACCESS | EXC_MASK_BAD_INSTRUCTION | EXC_MASK_ARITHMETIC
           | EXC_MASK_BREAKPOINT | EXC_MASK_GUARD;

    return mask;
}

bool registerHandler(ReadOnlyContext* context) {
    SPECTO_LOG_TRACE("Registering mach exception handler");

    mach_port_t task = mach_task_self();

    kern_return_t kr = mach_port_allocate(task, MACH_PORT_RIGHT_RECEIVE, &context->port);
    if (kr != KERN_SUCCESS) {
        SPECTO_LOG_ERROR("mach_port_allocate failed {}", kr);
        return false;
    }

    kr = mach_port_insert_right(task, context->port, context->port, MACH_MSG_TYPE_MAKE_SEND);
    if (kr != KERN_SUCCESS) {
        SPECTO_LOG_ERROR("mach_port_insert_right failed {}", kr);
        mach_port_deallocate(task, context->port);
        return false;
    }

    context->mask = exceptionMask();

    // ORing with MACH_EXCEPTION_CODES will produce 64-bit exception data
    kr = task_swap_exception_ports(task,
                                   context->mask,
                                   context->port,
                                   EXCEPTION_DEFAULT | MACH_EXCEPTION_CODES,
                                   THREAD_STATE_NONE,
                                   context->originalPorts.masks,
                                   &context->originalPorts.count,
                                   context->originalPorts.ports,
                                   context->originalPorts.behaviors,
                                   context->originalPorts.flavors);

    if (kr != KERN_SUCCESS) {
        SPECTO_LOG_ERROR("task_swap_exception_ports {}", kr);
        return false;
    }

    for (unsigned int i = 0; i < context->originalPorts.count; ++i) {
        SPECTO_LOG_TRACE("original ports: 0x{} 0x{} 0x{} 0x{}",
                         context->originalPorts.ports[i],
                         context->originalPorts.masks[i],
                         context->originalPorts.behaviors[i],
                         context->originalPorts.flavors[i]);
    }

    return true;
}

bool unregisterHandler(OriginalPorts* originalPorts, exception_mask_t mask) {
    kern_return_t kr;

    // Re-register all the old ports.
    for (mach_msg_type_number_t i = 0; i < originalPorts->count; ++i) {
        // clear the bits from this original mask
        mask &= ~originalPorts->masks[i];

        kr = task_set_exception_ports(mach_task_self(),
                                      originalPorts->masks[i],
                                      originalPorts->ports[i],
                                      originalPorts->behaviors[i],
                                      originalPorts->flavors[i]);
        if (kr != KERN_SUCCESS) {
            SPECTO_EXCEPTION_SAFE_LOG_WARN("unable to restore original port: {}",
                                           originalPorts->ports[i]);
        }
    }

    // Finally, mark any masks we registered for that do not have an original port as unused.
    kr = task_set_exception_ports(mach_task_self(),
                                  mask,
                                  MACH_PORT_NULL,
                                  EXCEPTION_DEFAULT | MACH_EXCEPTION_CODES,
                                  THREAD_STATE_NONE);
    if (kr != KERN_SUCCESS) {
        SPECTO_EXCEPTION_SAFE_LOG_ERROR("unable to unset unregistered mask: 0x{}", mask);
        return false;
    }

    return true;
}

#pragma mark - Recording

bool record(ReadOnlyContext* context, Message* message) {
    if (context == nullptr) {
        SPECTO_EXCEPTION_SAFE_LOG_ERROR("Aborting mach exception handler because context was null");
        return false;
    }

    if (message == nullptr) {
        SPECTO_EXCEPTION_SAFE_LOG_ERROR("Aborting mach exception handler because message was null");
        return false;
    }

    if (sig::markAndCheckIfCrashed()) {
        SPECTO_EXCEPTION_SAFE_LOG_ERROR(
          "Aborting mach exception handler because crash has already occurred");
        exit(1);
        return false;
    }

    SPECTO_EXCEPTION_SAFE_LOG_DEBUG("Creating mach exception marker file");

    for (std::size_t i = 0; i < util::countof(exceptions_); ++i) {
        const auto exception = exceptions_[i];
        if (exception == message->exception) {
            SPECTO_EXCEPTION_SAFE_LOG_DEBUG("Found the exception: %d", exception);
            const auto markerFilePath = context->markerFilePaths[i];
            const auto mask = O_WRONLY | O_CREAT;
            const auto fd = open(markerFilePath, mask, 0644);
            if (fd < 0) {
                SPECTO_EXCEPTION_SAFE_LOG_ERROR(
                  "Failed to create file at %s: errno %d", markerFilePath, errno);
                return false;
            }
            if (close(fd) < 0) {
                SPECTO_EXCEPTION_SAFE_LOG_ERROR(
                  "Failed to close created marker file at %s: errno %d", markerFilePath, errno);
                return false;
            }
        } else {
            SPECTO_EXCEPTION_SAFE_LOG_DEBUG("Exception was not %d", exception);
        }
    }

    return true;
}

#pragma mark - Messages

bool read(ReadOnlyContext* context, Message* message) {
    mach_msg_return_t r;

    memset(message, 0, sizeof(Message));

    r = mach_msg(&message->head,
                 MACH_RCV_MSG | MACH_RCV_LARGE,
                 0,
                 sizeof(Message),
                 context->port,
                 MACH_MSG_TIMEOUT_NONE,
                 MACH_PORT_NULL);
    if (r != MACH_MSG_SUCCESS) {
        SPECTO_EXCEPTION_SAFE_LOG_ERROR("Error receving mach_msg ({})", r);
        return false;
    }

    SPECTO_EXCEPTION_SAFE_LOG_DEBUG("Accepted mach exception message");

    return true;
}

kern_return_t dispatch(ReadOnlyContext* context, Message* message) {
    SPECTO_EXCEPTION_SAFE_LOG_DEBUG(
      "Mach exception: 0x%x, count: %u, code: 0x%llx 0x%llx",
      static_cast<int>(message->exception),
      static_cast<unsigned int>(message->codeCnt),
      static_cast<long long>(message->codeCnt > 0 ? message->code[0] : -1),
      static_cast<long long>(message->codeCnt > 1 ? message->code[1] : -1));

    // This will happen if a child process raises an exception, as the exception ports are
    // inherited.
    if (message->task.name != mach_task_self()) {
        SPECTO_EXCEPTION_SAFE_LOG_ERROR("Mach exception task mis-match, returning failure");
        return KERN_FAILURE;
    }

    SPECTO_EXCEPTION_SAFE_LOG_DEBUG("Unregistering handler");
    if (!unregisterHandler(&context->originalPorts, context->mask)) {
        SPECTO_EXCEPTION_SAFE_LOG_ERROR("Failed to unregister");
        return KERN_FAILURE;
    }

    SPECTO_EXCEPTION_SAFE_LOG_DEBUG("Restoring original signal handlers");
    if (!sig::reinstallOriginalHandlers()) {
        SPECTO_EXCEPTION_SAFE_LOG_ERROR("Failed to restore signal handlers");
        return KERN_FAILURE;
    }

    if (_enabled.load()) {
        SPECTO_EXCEPTION_SAFE_LOG_DEBUG("Recording mach exception");
        if (!record(context, message)) {
            SPECTO_EXCEPTION_SAFE_LOG_ERROR("Failed to record mach exception");
            return KERN_FAILURE;
        }
    }

    return KERN_SUCCESS;
}

bool reply(Message* message, kern_return_t result) {
    Reply reply;
    mach_msg_return_t r;

    // prepare the reply
    reply.head.msgh_bits = MACH_MSGH_BITS(MACH_MSGH_BITS_REMOTE(message->head.msgh_bits), 0);
    reply.head.msgh_remote_port = message->head.msgh_remote_port;
    reply.head.msgh_size = (mach_msg_size_t)sizeof(Reply);
    reply.head.msgh_local_port = MACH_PORT_NULL;
    reply.head.msgh_id = message->head.msgh_id + 100;

    reply.NDR = NDR_record;

    reply.retCode = result;

    SPECTO_EXCEPTION_SAFE_LOG_DEBUG("Sending exception reply");

    // send it
    r = mach_msg(&reply.head,
                 MACH_SEND_MSG,
                 reply.head.msgh_size,
                 0,
                 MACH_PORT_NULL,
                 MACH_MSG_TIMEOUT_NONE,
                 MACH_PORT_NULL);
    if (r != MACH_MSG_SUCCESS) {
        SPECTO_EXCEPTION_SAFE_LOG_ERROR("mach_msg reply failed (%d)", r);
        return false;
    }

    SPECTO_EXCEPTION_SAFE_LOG_DEBUG("Exception reply delivered");

    return true;
}

#pragma mark - Message server thread

void* serve(void* argument) {
    auto* context = static_cast<ReadOnlyContext*>(argument);

    pthread_setname_np("dev.specto.mach.exceptions.server");

    SPECTO_EXCEPTION_SAFE_LOG_DEBUG("About to start mach message server");

    while (true) {
        Message message;

        // read the exception message
        if (!read(context, &message)) {
            break;
        }

        // handle it, and possibly forward
        kern_return_t result = dispatch(context, &message);

        // and now, reply
        if (!reply(&message, result)) {
            break;
        }
    }

    SPECTO_EXCEPTION_SAFE_LOG_INFO("Mach message server thread exiting");

    return nullptr;
}

bool startServerThread(ReadOnlyContext* context) {
    pthread_attr_t attr;

    if (pthread_attr_init(&attr) != 0) {
        SPECTO_LOG_ERROR("pthread_attr_init {}", strerror(errno));
        return false;
    }

    if (pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED) != 0) {
        SPECTO_LOG_ERROR("pthread_attr_setdetachstate {}", strerror(errno));
        return false;
    }

    // Use to pre-allocate a stack for this thread
    // The stack must be page-aligned
    if (pthread_attr_setstack(
          &attr, _machExceptionContext.readonly->machStack, machExceptionHandlerStackSize_)
        != 0) {
        SPECTO_LOG_ERROR("pthread_attr_setstack {}", strerror(errno));
        return false;
    }

    if (pthread_create(&context->pthread, &attr, serve, context) != 0) {
        SPECTO_LOG_ERROR("pthread_create {}", strerror(errno));
        return false;
    }

    SPECTO_LOG_ERRNO(pthread_attr_destroy(&attr));

    context->thread = pthread_mach_thread_np(context->pthread);

    return true;
}

} // namespace

#pragma mark - Public API

void initialize(const fs::Path& markerFileDirectory, const fs::Path& logfilePath) {
    if (debugger::attached()) {
        SPECTO_LOG_WARN("Debugger present - not installing mach exception handlers");
        return;
    }

    SPECTO_LOG_DEBUG("Enabling mach exception handler.");
    _enabled = true;

    if (_machExceptionContext.allocator != nullptr) {
        SPECTO_LOG_DEBUG("Mach exception handlers already installed, nothing more to do.");
        return;
    }

    SPECTO_LOG_TRACE("Initializing mach exception handler.");

    // comment originally from Crashlytics (armcknight 6/19/2020):
    // create the allocator, and the contexts
    // The ordering here is really important, because the "stack" variable must be
    // page-aligned.  There's no mechanism to ask the allocator to do alignment, but we
    // do know the very first allocation in a region is aligned to a page boundary.

    _machExceptionContext.allocator =
      memory::initializeAllocator(minimumReadwriteSize_, minimumReadableSize_);

    _machExceptionContext.readonly = (ReadOnlyContext*)memory::allocate(
      _machExceptionContext.allocator, sizeof(ReadOnlyContext), memory::kReadOnly);
    std::memset(_machExceptionContext.readonly, 0, sizeof(ReadOnlyContext));

    _machExceptionContext.readonly->machStack = memory::allocate(
      _machExceptionContext.allocator, machExceptionHandlerStackSize_, memory::kReadWrite);
    std::memset(_machExceptionContext.readonly->machStack, 0, machExceptionHandlerStackSize_);

    _machExceptionContext.writable = (ReadWriteContext*)memory::allocate(
      _machExceptionContext.allocator, sizeof(ReadWriteContext), memory::kReadWrite);
    std::memset(_machExceptionContext.writable, 0, sizeof(ReadWriteContext));

    _machExceptionContext.writable->logFd = -1;
    _machExceptionContext.readonly->logLevel =
      static_cast<spdlog::level::level_enum>(SPECTO_ACTIVE_LOG_LEVEL);

    __sync_synchronize();

    _machExceptionContext.readonly->logPath =
      memory::readOnlyStringCopy(logfilePath.cString(), _machExceptionContext.allocator);

    for (std::size_t i = 0; i < util::countof(exceptions_); ++i) {
        const auto exception = exceptions_[i];

        const char* name = nullptr;
        exceptionNameLookup(exception, &name);

        auto path = fs::Path(markerFileDirectory.cString());
        path.appendComponent(name);

        _machExceptionContext.readonly->markerFilePaths[i] =
          memory::readOnlyStringCopy(path.cString(), _machExceptionContext.allocator);
    }

    if (!registerHandler(_machExceptionContext.readonly)) {
        SPECTO_LOG_ERROR("Unable to register mach exception handler");
        return;
    }

    if (!startServerThread(_machExceptionContext.readonly)) {
        SPECTO_LOG_ERROR("Unable to start thread");
        unregisterHandler(&_machExceptionContext.readonly->originalPorts,
                          _machExceptionContext.readonly->mask);
    }

    __sync_synchronize();

    SPECTO_LOG_TRACE("Protecting mach exception context read only memory");
    memory::protectReadOnlyMemory(_machExceptionContext.allocator);
}

void exceptionNameLookup(int exception, const char** name) {
    if (!name) {
        return;
    }

    switch (exception) {
        case EXC_BAD_ACCESS:
            *name = "EXC_BAD_ACCESS";
            break;
        case EXC_BAD_INSTRUCTION:
            *name = "EXC_BAD_INSTRUCTION";
            break;
        case EXC_ARITHMETIC:
            *name = "EXC_ARITHMETIC";
            break;
        case EXC_GUARD:
            *name = "EXC_GUARD";
            break;
        case EXC_BREAKPOINT:
            *name = "EXC_BREAKPOINT";
            break;
        default:
            *name = "UNKNOWN";
            break;
    }
}

void disable() {
    SPECTO_LOG_DEBUG("Disabling mach exception handler.");
    _enabled = false;
}

} // namespace specto::darwin::exception
