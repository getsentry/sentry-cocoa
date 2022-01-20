// Copyright (c) Specto Inc. All rights reserved.

#include "Path.h"

#include "Log.h"

#include <algorithm>
#include <libgen.h>
#include <memory>
#include <new>
#include <utility>

namespace {
bool isDirectorySeparator(int ch) {
    return (ch == '/') || (ch == '\\');
}

void leftTrimDirectorySeparators(std::string &s) {
    s.erase(s.begin(), std::find_if(s.begin(), s.end(), [](int ch) {
                return !isDirectorySeparator(ch) && (ch != '\0');
            }));
}

void rightTrimDirectorySeparators(std::string &s) {
    s.erase(std::find_if(s.rbegin(),
                         s.rend(),
                         [](int ch) { return !isDirectorySeparator(ch) && (ch != '\0'); })
              .base(),
            s.end());
}

std::unique_ptr<char[]> copyAsCString(const std::string &s) noexcept {
    const auto buflen = s.length() + 1;
    std::unique_ptr<char[]> buf(new (std::nothrow) char[buflen]);
    if (buf == nullptr) {
        return buf;
    }
    std::strncpy(buf.get(), s.c_str(), buflen);
    return buf;
}

std::pair<std::string, std::string> splitStemExtension(const std::string &s) {
    const auto pos = s.find_last_of('.');
    if (pos == std::string::npos) {
        return std::make_pair(s, "");
    } else {
        return std::make_pair(s.substr(0, pos), s.substr(pos + 1));
    }
}

} // namespace

namespace specto::filesystem {

Path::Path() noexcept : path_({}) { }

Path::Path(const char *str) noexcept : Path(str == nullptr ? std::string {} : std::string(str)) { }

Path::Path(std::string str) noexcept {
    if (str.empty()) {
        path_ = "";
    } else {
        std::string strCopy = str;
        rightTrimDirectorySeparators(strCopy);
        if (strCopy.empty()) {
            path_ = std::move(str);
        } else {
            path_ = std::move(strCopy);
        }
    }
}

Path Path::join(const std::vector<std::string> &components) noexcept {
    if (components.empty()) {
        return Path {};
    }
    auto path = Path(components[0]);
    if (components.size() > 1) {
        auto it = components.cbegin();
        std::advance(it, 1);
        while (it != components.cend()) {
            path.appendComponent(*it);
            it++;
        }
    }
    return path;
}

void Path::appendComponent(std::string component) {
    leftTrimDirectorySeparators(component);
    rightTrimDirectorySeparators(component);
    path_.append("/");
    path_.append(component);
}

bool Path::empty() const noexcept {
    return path_.empty();
}

std::string Path::string() const noexcept {
    return path_;
}

std::size_t Path::length() const noexcept {
    return path_.length();
}

const char *Path::cString() const noexcept {
    return path_.c_str();
}

Path Path::parentPath() const noexcept {
    // Copy the string, because dirname() can mutate its input buffer.
    // https://linux.die.net/man/3/dirname
    const auto pathCopyPtr = copyAsCString(path_);
    char *rv;
    // The Linux man page doesn't document this, but the Mac OS X documentation
    // notes that dirname() will set errno and return nullptr upon failure:
    // https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/dirname.3.html
    if (SPECTO_LOG_ERRNO(rv = dirname(pathCopyPtr.get())) == nullptr) {
        return {};
    }
    return Path(std::string(rv));
}

std::string Path::baseName() const noexcept {
    // Copy the string, because basename() can mutate its input buffer.
    // https://linux.die.net/man/3/basename
    const auto pathCopyPtr = copyAsCString(path_);
    char *rv;
    // The Linux man page doesn't document this, but the Mac OS X documentation
    // notes that basename() will set errno and return nullptr upon failure:
    // https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/basename.3.html
    if (SPECTO_LOG_ERRNO(rv = basename(pathCopyPtr.get())) == nullptr) {
        return {};
    }
    return std::string(rv);
}

std::string Path::stem() const {
    return splitStemExtension(baseName()).first;
}

std::string Path::extension() const {
    return splitStemExtension(baseName()).second;
}

bool Path::operator==(const Path &other) const noexcept {
    return path_ == other.path_;
}

bool Path::operator!=(const Path &other) const noexcept {
    return path_ != other.path_;
}

Path::operator std::string() const noexcept {
    return path_;
}

} // namespace specto::filesystem
