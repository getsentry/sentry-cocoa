// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/filesystem/src/Path.h"

using namespace specto::filesystem;

TEST(PathTest, TestInitializeEmptyPath) {
    EXPECT_EQ(Path("").string(), "");
}

TEST(PathTest, TestInitializePathWithTrailingDirectorySeparator) {
    EXPECT_EQ(Path("foo/").string(), "foo");
}

TEST(PathTest, TestInitializePathWithMultipleTrailingDirectorySeparator) {
    EXPECT_EQ(Path("foo//").string(), "foo");
}

TEST(PathTest, TestInitializePathWithLeadingDirectorySeparator) {
    EXPECT_EQ(Path("/foo").string(), "/foo");
}

TEST(PathTest, TestInitializePathWithMultiplePathComponents) {
    EXPECT_EQ(Path("foo/bar/baz").string(), "foo/bar/baz");
}

TEST(PathTest, TestEmptyForEmptyPath) {
    EXPECT_TRUE(Path("").empty());
}

TEST(PathTest, TestEmptyForNonEmptyPath) {
    EXPECT_FALSE(Path("foo").empty());
}

TEST(PathTest, TestJoinPathComponents) {
    EXPECT_EQ(Path::join({"foo", "bar", "baz"}).string(), "foo/bar/baz");
}

TEST(PathTest, TestJoinPathComponentsWithLeadingDirectorySeparators) {
    EXPECT_EQ(Path::join({"/foo", "/bar", "/baz"}).string(), "/foo/bar/baz");
}

TEST(PathTest, TestJoinPathComponentsWithTrailingDirectorySeparators) {
    EXPECT_EQ(Path::join({"foo/", "bar/", "baz/"}).string(), "foo/bar/baz");
}

TEST(PathTest, TestJoinPathComponentsWithLeadingAndTrailingDirectorySeparators) {
    EXPECT_EQ(Path::join({"/foo/", "/bar/", "/baz/"}).string(), "/foo/bar/baz");
}

TEST(PathTest, TestAppendComponent) {
    Path path("foo");
    path.appendComponent("bar");
    EXPECT_EQ(path.string(), "foo/bar");
}

TEST(PathTest, TestAppendComponentWithLeadingDirectorySeparator) {
    Path path("foo");
    path.appendComponent("/bar");
    EXPECT_EQ(path.string(), "foo/bar");
}

TEST(PathTest, TestAppendComponentWithTrailingDirectorySeparator) {
    Path path("foo");
    path.appendComponent("bar/");
    EXPECT_EQ(path.string(), "foo/bar");
}

TEST(PathTest, TestAppendComponentWithLeadingAndTrailingDirectorySeparators) {
    Path path("foo");
    path.appendComponent("/bar/");
    EXPECT_EQ(path.string(), "foo/bar");
}

TEST(PathTest, TestCStr) {
    EXPECT_STREQ(Path("foo/bar/baz").cString(), "foo/bar/baz");
}

TEST(PathTest, TestLength) {
    EXPECT_EQ(Path("foo/bar/baz").length(), 11);
}

TEST(PathTest, TestParentPath) {
    EXPECT_EQ(Path("foo/bar").parentPath().string(), "foo");
}

TEST(PathTest, TestParentPathOfRelativePathWithNoParent) {
    EXPECT_EQ(Path("foo").parentPath().string(), ".");
}

TEST(PathTest, TestParentPathOfAbsolutePathWithNoParent) {
    EXPECT_EQ(Path("/").parentPath().string(), "/");
}

TEST(PathTest, TestBaseNameWithNoExtension) {
    EXPECT_EQ(Path("foo/bar").baseName(), "bar");
}

TEST(PathTest, TestBaseNameWithExtension) {
    EXPECT_EQ(Path("foo/bar.txt").baseName(), "bar.txt");
}

TEST(PathTest, TestBaseNameWithTrailingDirectorySeparator) {
    EXPECT_EQ(Path("foo/bar/").baseName(), "bar");
}

TEST(PathTest, TestStemWithNoExtension) {
    EXPECT_EQ(Path("foo/bar").stem(), "bar");
}

TEST(PathTest, TestStemWithExtension) {
    EXPECT_EQ(Path("foo/bar.txt").stem(), "bar");
}

TEST(PathTest, TestStemWithMultipleExtensions) {
    EXPECT_EQ(Path("foo/bar.txt.zip").stem(), "bar.txt");
}

TEST(PathTest, TestExtensionithNoExtension) {
    EXPECT_EQ(Path("foo/bar").extension(), "");
}

TEST(PathTest, TestExtensionWithExtension) {
    EXPECT_EQ(Path("foo/bar.txt").extension(), "txt");
}

TEST(PathTest, TestExtensionWithMultipleExtensions) {
    EXPECT_EQ(Path("foo/bar.txt.zip").extension(), "zip");
}

TEST(PathTest, TestEqualityForEqualPaths) {
    EXPECT_EQ(Path("foo/bar.txt.zip"), Path("foo/bar.txt.zip"));
}

TEST(PathTest, TestEqualityForNonEqualPaths) {
    EXPECT_NE(Path("foo/bar.txt"), Path("foo/bar.txt.zip"));
}
