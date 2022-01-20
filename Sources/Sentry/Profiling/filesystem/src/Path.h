// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include <string>
#include <vector>

namespace specto::filesystem {

/** An abstraction that represents a filesystem path. */
class Path {
public:
    /** Constructs an empty path. */
    Path() noexcept;

    /** Constructs a new path from a string. */
    explicit Path(std::string str) noexcept;

    /** Constructs a new path from a string. */
    explicit Path(const char *str) noexcept;

    /**
     * Constructs a path by joining path components.
     * @param components The components to join.
     * @return A Path object construted by joining the components.
     */
    static Path join(const std::vector<std::string> &components) noexcept;

    /**
     * Appends a component to the path.
     * @param component The component to append. A leading directory separator (slash) will
     * automatically be appended, `component` does not need to contain one. A trailing directory
     * separator will NOT be appended. If `component` contains a leading and/or trailing directory
     * separator, it will be stripped before appending.
     */
    void appendComponent(std::string component);

    /** @return Whether the path is empty or not. */
    [[nodiscard]] bool empty() const noexcept;

    /** @return The path as a string. */
    [[nodiscard]] std::string string() const noexcept;

    /** @return The length of the path. */
    [[nodiscard]] std::size_t length() const noexcept;

    /**
     * Returns a C-string representation of the path. This reference will be invalid if the parent
     * Path object is destructed.
     */
    [[nodiscard]] const char *cString() const noexcept;

    /**
     * @return The path to the parent directory, without the trailing directory separator.
     * Upon failure, returns an empty string.
     */
    [[nodiscard]] Path parentPath() const noexcept;

    /**
     * @return The base component of the path (the last component following the trailing directory
     * separator), without a leading directory separator.
     */
    [[nodiscard]] std::string baseName() const noexcept;

    /** @return The base name without the file extension. */
    [[nodiscard]] std::string stem() const;

    /** @return The file extension if one exists, or an empty string otherwise. */
    [[nodiscard]] std::string extension() const;

    bool operator==(const Path &other) const noexcept;
    bool operator!=(const Path &other) const noexcept;
    explicit operator std::string() const noexcept;

private:
    std::string path_;
};

} // namespace specto::filesystem
