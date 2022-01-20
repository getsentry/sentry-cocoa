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

#include "Handling.h"

#include "cpp/debugger/src/Debugger.h"
#include "cpp/filesystem/src/Filesystem.h"
#include "cpp/io/src/IO.h"

#include <atomic>
#include <csignal>
#include <dlfcn.h>
#include <sys/fcntl.h>
#include <unistd.h>

#if !defined(NDEBUG)
#define SPECTO_SIGNAL_SAFE_LOG_DEBUG(__FORMAT__, ...) \
    signalSafeLog(                                    \
      spdlog::level::debug, "[debug] [%s:%d] " __FORMAT__ "\n", __FILE__, __LINE__, ##__VA_ARGS__)
#define SPECTO_SIGNAL_SAFE_LOG_INFO(__FORMAT__, ...) \
    signalSafeLog(                                   \
      spdlog::level::info, "[info] [%s:%d] " __FORMAT__ "\n", __FILE__, __LINE__, ##__VA_ARGS__)
#else
#define SPECTO_SIGNAL_SAFE_LOG_DEBUG(__FORMAT__, ...)
#define SPECTO_SIGNAL_SAFE_LOG_INFO(__FORMAT__, ...)
#endif
#define SPECTO_SIGNAL_SAFE_LOG_WARN(__FORMAT__, ...) \
    signalSafeLog(                                   \
      spdlog::level::warn, "[warn] [%s:%d] " __FORMAT__ "\n", __FILE__, __LINE__, ##__VA_ARGS__)
#define SPECTO_SIGNAL_SAFE_LOG_ERROR(__FORMAT__, ...) \
    signalSafeLog(                                    \
      spdlog::level::err, "[error] [%s:%d] " __FORMAT__ "\n", __FILE__, __LINE__, ##__VA_ARGS__)

namespace specto::signal {

namespace {

#pragma mark - Declarations

SignalHandlingContext signalHandlingContext_;

static_assert(ATOMIC_BOOL_LOCK_FREE == 2, "Signal handler toggling requires async-safe state.");
std::atomic_bool enabled_ {false};

/**
 * per man sigaltstack, MINSIGSTKSZ is the minimum *overhead* needed to support
 * a signal stack.  The actual stack size must be larger.  Let's pick the recommended
 * size.
 */
constexpr auto signalHandlerStackSize_ = SIGSTKSZ * 2;

/**
 * The writable size is our handler stack plus whatever scratch we need. We have to use this space
 * extremely carefully, however, because thread stacks always needs to be page-aligned.  Only the
 * first allocation is guaranteed to be page-aligned.
 */
constexpr auto minimumReadwriteSize_ = signalHandlerStackSize_ + sizeof(ReadWriteContext);

/**
 * We need enough space here for the context, plus storage for strings.
 */
constexpr auto minimumReadableSize_ = sizeof(ReadOnlyContext) + 4096 * 4;

/** This is the function whose pointer is passed to the system signal handler registration function.
 */
void signalHandler(int signal, siginfo_t *info, __unused void *uapVoid);

/**
 * Install a handler for each signal we want to catch, while preserving the reference to any
 * previous custom handlers that may have been installed.
 */
void installHandlers(ReadOnlyContext *readOnlyContext);

#pragma mark - Implementations

/**
 * @note There are lots of things that can fail here, hence all the early returns, but we can never
 * really know if/how it happens in the wild, since we can't log anything!
 * @warningDon't call directly; use one of the SPECTO_SIGNAL_SAFE_LOG_ macros.
 */
void signalSafeLog(spdlog::level::level_enum level, const char *format, ...) {
    if ((signalHandlingContext_.readonly == nullptr)
        || (signalHandlingContext_.writable == nullptr)) {
        return;
    }

    const auto path = signalHandlingContext_.readonly->logPath;
    if (!SPECTO_IS_VALID_POINTER(path)) {
        return;
    }

    if (signalHandlingContext_.readonly->logLevel > level) {
        return;
    }

    if (signalHandlingContext_.writable->logFd == -1) {
        signalHandlingContext_.writable->logFd = fs::fileDescriptorForPath(path, true);
    }

    const auto fd = signalHandlingContext_.writable->logFd;
    if (fd < 0) {
        return;
    }

    va_list args;
    va_start(args, format);
    io::async_safe::safeWrite(fd, format, args);
    va_end(args);
}

bool isInitialized() {
    __sync_synchronize();
    if (!SPECTO_IS_VALID_POINTER(signalHandlingContext_.readonly)) {
        return false;
    }

    return signalHandlingContext_.readonly->initialized;
}

void recordSignal(siginfo_t *info) {
    if (signalHandlingContext_.readonly == nullptr) {
        return;
    }

    if (markAndCheckIfCrashed()) {
        SPECTO_SIGNAL_SAFE_LOG_ERROR("aborting signal handler because crash has already occurred");
        std::exit(1);
        return;
    }

    if (SPECTO_IS_VALID_POINTER(info)) {
        for (std::size_t idx = 0; idx < util::countof(fatalSignals_); ++idx) {
            const auto signal = fatalSignals_[idx];

            if (signal == info->si_signo) {
                const auto markerFilePath = signalHandlingContext_.readonly->signalMarkerPaths[idx];
                const auto mask = O_WRONLY | O_CREAT;
                const auto fd = open(markerFilePath, mask, 0644);
                if (fd < 0) {
                    SPECTO_SIGNAL_SAFE_LOG_ERROR(
                      "Failed to create file at %s: errno %d", markerFilePath, errno);
                }
                if (close(fd) < 0) {
                    SPECTO_SIGNAL_SAFE_LOG_ERROR(
                      "Failed to close created marker file at %s: errno %d", markerFilePath, errno);
                }
            }
        }
    }
}

void removeSpectoHandlers() {
    for (int signal : fatalSignals_) {
        struct sigaction sa;

        sa.sa_handler = SIG_DFL;
        sigemptyset(&sa.sa_mask);

        if (sigaction(signal, &sa, nullptr) != 0) {
            SPECTO_SIGNAL_SAFE_LOG_WARN(
              "Unable to set default handler for %d (%s)", signal, strerror(errno));
        }
    }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-function"
// this function is only called from macros, and the compiler warns that it's never called
const char *handlerName(struct sigaction previousAction) {
    const auto previousHandler = previousAction.__sigaction_u.__sa_handler;
    Dl_info previousHandlerInfo;
    const char *previousHandlerName = nullptr;
    if (dladdr(reinterpret_cast<void *>(previousHandler), &previousHandlerInfo) != 0) {
        previousHandlerName = previousHandlerInfo.dli_sname;
    }
    return previousHandlerName;
}
#pragma clang diagnostic pop

/**
 * Re-install handlers already registered at the time we registered, making sure the handler for
 * the signal we caught is given a chance to run.
 * @param readOnlyContext The read-only struct used to store data needed in signal handlers.
 * @param currentSignal The signal we caught and want to propagate to any other handlers.
 * @param info A pointer (to space on the stack) to a siginfo_t structure, which provides additional
 * detail about the delivery of the signal.
 * @param uapVoid A pointer (again to space on the stack) to a ucontext_t structure (defined in
 * <sys/ucontext.h>) which contains the context from before the signal.
 */
bool propagateSignal(ReadOnlyContext *readOnlyContext,
                     const int currentSignal,
                     siginfo_t *info,
                     void *uapVoid) {
    removeSpectoHandlers();

    // re-install the original stack, if needed
    if (readOnlyContext->originalStack.ss_sp != nullptr) {
        SPECTO_SIGNAL_SAFE_LOG_DEBUG("Reinstalling original stack");
        if (sigaltstack(&readOnlyContext->originalStack, nullptr) != 0) {
            SPECTO_SIGNAL_SAFE_LOG_WARN("Unable to setup stack %s", strerror(errno));
            return false;
        }
    }

    __block auto success = true;
    for (std::size_t idx = 0; idx < util::countof(fatalSignals_); ++idx) {
        const auto signal = fatalSignals_[idx];

        const auto previousAction = readOnlyContext->originalActions[idx];

        // these casts are here to satisfy compiler warnings in the following if/else comparisons.
        // SIG_DFL is defined as 0, and SIG_IGN as 1, so we're really just comparing 0s and/or 1s
        // that are stored in pointer variables. see the comment at the definition of SIG_DFL in
        // sys/signal.h for details on the pointer types –armcknight 2020/04/21
        const auto defaultHandler =
          reinterpret_cast<void (*)(int, struct __siginfo *, void *)>(SIG_DFL);
        const auto ignoreHandler =
          reinterpret_cast<void (*)(int, struct __siginfo *, void *)>(SIG_IGN);

        if (previousAction.sa_sigaction == defaultHandler) {
            SPECTO_SIGNAL_SAFE_LOG_DEBUG("Reinstalling SIG_DFL for signal %d", signal);
            struct sigaction sa;
            sa.sa_handler = SIG_DFL;
            sigemptyset(&sa.sa_mask);
            if (sigaction(signal, &sa, nullptr) != 0) {
                SPECTO_SIGNAL_SAFE_LOG_WARN(
                  "Unable to set default handler for %d (%s)", signal, strerror(errno));
                success = false;
            }
            if (currentSignal < 0) {
                continue;
            }
            if (signal == currentSignal) {
                SPECTO_SIGNAL_SAFE_LOG_DEBUG("Reraising signal %d", signal);
                raise(signal);
            }

            // many online examples show reinstalling your handler again after reraising the signal;
            // because we're only interested in terminating signals, and ensure we only handle each
            // signal once, it wouldn't make sense to reinstall ourselves after reraising the signal
            // –armcknight 2020/04/21
            continue;
        }
        if (previousAction.sa_sigaction == ignoreHandler) {
            SPECTO_SIGNAL_SAFE_LOG_DEBUG("Previous handler is SIG_IGN, do nothing", signal);
            continue;
        }

        if (signal == currentSignal) {
            SPECTO_SIGNAL_SAFE_LOG_DEBUG(
              "Calling previously installed handler for %d at the time of "
              "our handler registration: %s",
              signal,
              handlerName(previousAction));
            const auto action = previousAction.sa_sigaction;
            action(signal, info, uapVoid);
        }
    }

    return success;
}

void signalHandler(int signal, siginfo_t *info, __unused void *uapVoid) {
    sigset_t set;

    // save errno, both because it is interesting, and so we can restore it afterwards
    const auto savedErrno = errno;
    errno = 0;

    SPECTO_SIGNAL_SAFE_LOG_WARN("Signal: %d", signal);

    // it is important to do this before unmasking signals, otherwise we can get
    // called in a loop
    removeSpectoHandlers();

    sigfillset(&set);
    if (sigprocmask(SIG_UNBLOCK, &set, nullptr) != 0) {
        SPECTO_SIGNAL_SAFE_LOG_WARN("Unable to unmask signals - we risk infinite recursion here");
    }

    // check info and uapVoid, and set them to appropriate values if invalid.  This can happen
    // if we have been called without the SA_SIGINFO flag set
    if (!SPECTO_IS_VALID_POINTER(info)) {
        info = nullptr;
    }

    if (!SPECTO_IS_VALID_POINTER(uapVoid)) {
        uapVoid = nullptr;
    }

    if (enabled_.load()) {
        recordSignal(info);
    }

    if (signalHandlingContext_.readonly != nullptr) {
        propagateSignal(signalHandlingContext_.readonly, signal, info, uapVoid);
    }

    // the process has crashed if execution reaches this point, so we don't need to worry about
    // reinstalling our handlers (armcknight 11 Jan 2021)

    // restore errno
    errno = savedErrno;
}

void allocate(SignalHandlingContext *context) {
    // comment originally from Crashlytics (armcknight 6/19/2020):
    // create the allocator, and the contexts
    // The ordering here is really important, because the "stack" variable must be
    // page-aligned.  There's no mechanism to ask the allocator to do alignment, but we
    // do know the very first allocation in a region is aligned to a page boundary.

    context->allocator = memory::initializeAllocator(minimumReadwriteSize_, minimumReadableSize_);

    context->readonly = static_cast<ReadOnlyContext *>(
      memory::allocate(context->allocator, sizeof(ReadOnlyContext), memory::kReadOnly));
    std::memset(context->readonly, 0, sizeof(ReadOnlyContext));

    context->readonly->signalStack =
      memory::allocate(context->allocator, signalHandlerStackSize_, memory::kReadWrite);
    std::memset(context->readonly->signalStack, 0, signalHandlerStackSize_);

    context->writable = static_cast<ReadWriteContext *>(
      memory::allocate(context->allocator, sizeof(ReadWriteContext), memory::kReadWrite));
    std::memset(context->writable, 0, sizeof(ReadWriteContext));
}

void installAltStack(ReadOnlyContext *readOnlyContext) {
    stack_t signalStack;
    stack_t originalStack;

    signalStack.ss_sp = signalHandlingContext_.readonly->signalStack;
    signalStack.ss_size = signalHandlerStackSize_;
    signalStack.ss_flags = 0;

    if (sigaltstack(&signalStack, &originalStack) != 0) {
        SPECTO_LOG_WARN("Unable to setup stack {}", strerror(errno));
        return;
    }

    readOnlyContext->originalStack.ss_sp = nullptr;
    readOnlyContext->originalStack = originalStack;
}

void installHandlers(ReadOnlyContext *readOnlyContext) {
    for (std::size_t idx = 0; idx < util::countof(fatalSignals_); ++idx) {
        const auto signal = fatalSignals_[idx];

        struct sigaction action;
        struct sigaction previousAction;

        action.sa_sigaction = signalHandler;

        // SA_RESETHAND seems like it would be great, but it doesn't appear to
        // work correctly.  After taking a signal, causing another identical signal in
        // the handler will *not* cause the default handler to be invoked (which should
        // terminate the process).  I've found some evidence that others have seen this
        // behavior on MAC OS X. –comment from Crashlytics source
        //
        // see http://openradar.appspot.com/11839803, not sure if this has been fixed –armcknight
        // 2020/04/21
        action.sa_flags = SA_SIGINFO | SA_ONSTACK;

        sigemptyset(&action.sa_mask);

        previousAction.sa_sigaction = nullptr;
        if (sigaction(signal, &action, &previousAction) != 0) {
            SPECTO_LOG_WARN("Unable to install handler for {} ({}})\n", signal, strerror(errno));
        }

        // store the last action, so it can be recalled
        readOnlyContext->originalActions[idx].sa_sigaction = nullptr;

        if (previousAction.sa_sigaction != nullptr) {
            SPECTO_LOG_DEBUG("Found previous signal handler ({}), stored on stack",
                             handlerName(previousAction));
            readOnlyContext->originalActions[idx] = previousAction;
        }
    }
}

} // namespace

#pragma mark - Public

void initializeSignalHandling(const fs::Path &markerFileDirectoryPath,
                              const fs::Path &crashLogPath) {
    if (debugger::attached()) {
        SPECTO_LOG_WARN("Debugger present - not installing signal handlers");
        return;
    }

    SPECTO_LOG_DEBUG("Enabling signal handler.");
    enabled_ = true;

    if (signalHandlingContext_.allocator != nullptr) {
        SPECTO_LOG_DEBUG("Signal handler already setup, nothing else to do.");
        return;
    }

    SPECTO_LOG_TRACE("Initializing signal handler.");

    allocate(&signalHandlingContext_);

    signalHandlingContext_.writable->logFd = -1;
    signalHandlingContext_.writable->crashOccurred = false;

    signalHandlingContext_.readonly->logLevel =
      static_cast<spdlog::level::level_enum>(SPECTO_ACTIVE_LOG_LEVEL);
    signalHandlingContext_.readonly->initialized = false;
    __sync_synchronize();

    signalHandlingContext_.readonly->logPath =
      memory::readOnlyStringCopy(crashLogPath.cString(), signalHandlingContext_.allocator);

    SPECTO_LOG_TRACE("Signal handler will place marker files in directory {}",
                     markerFileDirectoryPath.cString());
    // set up the marker file path for each signal, which is simply named by the name of the signal
    for (std::size_t idx = 0; idx < util::countof(fatalSignals_); ++idx) {
        const auto signal = fatalSignals_[idx];
        const char *name = nullptr;
        signalNameLookup(signal, &name);

        auto markerFilePath = filesystem::Path(markerFileDirectoryPath.cString());
        markerFilePath.appendComponent(std::string(name));

        const auto copiedPath =
          memory::readOnlyStringCopy(markerFilePath.cString(), signalHandlingContext_.allocator);
        signalHandlingContext_.readonly->signalMarkerPaths[idx] = copiedPath;
    }

    installAltStack(signalHandlingContext_.readonly);
    installHandlers(signalHandlingContext_.readonly);

#if TARGET_IPHONE_SIMULATOR
    // prevent the OpenGL stack (by way of OpenGLES.framework/libLLVMContainer.dylib) from
    // installing signal handlers that do not chain back
    // TODO: I don't believe this is necessary as of recent iOS releases
    bool *ptr = (bool *)dlsym(RTLD_DEFAULT, "_ZN4llvm23DisablePrettyStackTraceE");
    if (ptr) {
        *ptr = true;
    }
#endif

    signalHandlingContext_.readonly->initialized = true;
    __sync_synchronize();

    if (!memory::protectReadOnlyMemory(signalHandlingContext_.allocator)) {
        SPECTO_LOG_ERROR("Memory protection failed");
    }
}

void signalNameLookup(int signal, const char **name) {
    if (name == nullptr) {
        return;
    }

    switch (signal) {
        case SIGABRT:
            *name = "SIGABRT";
            break;
        case SIGBUS:
            *name = "SIGBUS";
            break;
        case SIGFPE:
            *name = "SIGFPE";
            break;
        case SIGILL:
            *name = "SIGILL";
            break;
        case SIGSEGV:
            *name = "SIGSEGV";
            break;
        case SIGSYS:
            *name = "SIGSYS";
            break;
        case SIGTRAP:
            *name = "SIGTRAP";
            break;
        default:
            *name = "UNKNOWN";
            break;
    }
}

bool markAndCheckIfCrashed() {
    if (!isInitialized()) {
        SPECTO_SIGNAL_SAFE_LOG_WARN("Checking if crashed, but not initialized.");
        return false;
    }

    if (signalHandlingContext_.writable->crashOccurred) {
        SPECTO_SIGNAL_SAFE_LOG_WARN("Crash has already occurred.");
        return true;
    }

    signalHandlingContext_.writable->crashOccurred = true;
    __sync_synchronize();

    SPECTO_SIGNAL_SAFE_LOG_DEBUG("Reporting that no previous crash was being handled and marking "
                                 "that a crash is now being handled.");
    return false;
}

bool reinstallOriginalHandlers() {
    // passing -1, nullptr, nullptr is an implementation detail carried over from Crashlytics, so it
    // installs the previous handler but doesn't raise any signal
    return propagateSignal(signalHandlingContext_.readonly, -1, nullptr, nullptr);
}

void disable() {
    SPECTO_LOG_DEBUG("Disabling signal handler.");
    enabled_ = false;
}

} // namespace specto::signal
