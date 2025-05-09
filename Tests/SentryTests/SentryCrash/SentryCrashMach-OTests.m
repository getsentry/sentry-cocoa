// Adapted from: https://github.com/kstenerud/KSCrash
//
//  KSMach-O_Tests.m
//
//  Copyright (c) 2019 YANDEX LLC. All rights reserved.
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

#import "SentryCrashMach-O.h"
#import <XCTest/XCTest.h>
#import <mach-o/loader.h>
#import <mach/mach.h>

@interface SentryCrashMach_O_Tests : XCTestCase
@end

@implementation SentryCrashMach_O_Tests

- (void)testGetCommandByTypeFromHeader_SegmentArchDependent
{
    // Arrange

    // Create a test Mach-O header
    mach_header_t header;
    header.ncmds = 1;

    // Create a command
    struct load_command cmd1;
    cmd1.cmd = LC_SEGMENT_ARCH_DEPENDENT;
    cmd1.cmdsize = sizeof(struct load_command);

    // Copy the command into the header memory
    uint8_t buffer[sizeof(header) + sizeof(cmd1)];
    memcpy(buffer, &header, sizeof(header));
    memcpy(buffer + sizeof(header), &cmd1, sizeof(cmd1));

    const mach_header_t *testHeader = (mach_header_t *)buffer;

    // Act
    const struct load_command *result
        = sentrycrash_macho_getCommandByTypeFromHeader(testHeader, LC_SEGMENT_ARCH_DEPENDENT);

    // Assert
    XCTAssertNotEqual(result, NULL);
    XCTAssertEqual(result->cmd, LC_SEGMENT_ARCH_DEPENDENT);
}

- (void)testGetCommandByTypeFromHeader_Symtab
{
    // Arrange

    // Create a test Mach-O header
    mach_header_t header;
    header.ncmds = 1;

    // Create a command
    struct load_command cmd2;
    cmd2.cmd = LC_SYMTAB;
    cmd2.cmdsize = sizeof(struct load_command);

    // Copy the command into the header memory
    uint8_t buffer[sizeof(header) + sizeof(cmd2)];
    memcpy(buffer, &header, sizeof(header));
    memcpy(buffer + sizeof(header), &cmd2, sizeof(cmd2));

    const mach_header_t *testHeader = (mach_header_t *)buffer;

    // Act
    const struct load_command *result
        = sentrycrash_macho_getCommandByTypeFromHeader(testHeader, LC_SYMTAB);

    // Assert
    XCTAssertNotEqual(result, NULL);
    XCTAssertEqual(result->cmd, LC_SYMTAB);
}

- (void)testGetCommandByTypeFromHeader_NotFound
{
    // Arrange

    // Create a test Mach-O header
    mach_header_t header;
    header.ncmds = 1;

    // Create a command
    struct load_command cmd1;
    cmd1.cmd = LC_SEGMENT_ARCH_DEPENDENT;
    cmd1.cmdsize = sizeof(struct load_command);

    // Copy the command into the header memory
    uint8_t buffer[sizeof(header) + sizeof(cmd1)];
    memcpy(buffer, &header, sizeof(header));
    memcpy(buffer + sizeof(header), &cmd1, sizeof(cmd1));

    const mach_header_t *testHeader = (mach_header_t *)buffer;

    // Act
    const struct load_command *result
        = sentrycrash_macho_getCommandByTypeFromHeader(testHeader, LC_DYSYMTAB);

    // Assert
    XCTAssertEqual(result, NULL);
}

- (void)testGetCommandByTypeFromHeader_InvalidHeader
{
    // Arrange & Act
    const struct load_command *result
        = sentrycrash_macho_getCommandByTypeFromHeader(NULL, LC_SEGMENT_ARCH_DEPENDENT);

    // Assert
    XCTAssertEqual(result, NULL);
}

- (void)testGetCommandByTypeFromHeader_InvalidCommand
{
    // Arrange

    // Create a test Mach-O header
    mach_header_t header;
    header.ncmds = 1;

    // Create a command
    struct load_command cmd2;
    cmd2.cmd = LC_SYMTAB;
    cmd2.cmdsize = sizeof(struct load_command);

    // Copy the command into the header memory
    uint8_t buffer[sizeof(header) + sizeof(cmd2)];
    memcpy(buffer, &header, sizeof(header));
    memcpy(buffer + sizeof(header), &cmd2, sizeof(cmd2));

    const mach_header_t *testHeader = (mach_header_t *)buffer;

    // Act
    const struct load_command *result
        = sentrycrash_macho_getCommandByTypeFromHeader(testHeader, UINT32_MAX);

    // Assert
    XCTAssertEqual(result, NULL);
}

- (void)testGetSegmentByNameFromHeader_TextSegment
{
    // Arrange

    // Create a test Mach-O header
    mach_header_t header;
    header.ncmds = 1;

    // Create a segment
    segment_command_t seg1;
    seg1.cmd = LC_SEGMENT_ARCH_DEPENDENT;
    seg1.cmdsize = sizeof(segment_command_t);
    strcpy(seg1.segname, "__TEXT");

    // Copy the segment into the header memory
    uint8_t buffer[sizeof(header) + sizeof(seg1)];
    memcpy(buffer, &header, sizeof(header));
    memcpy(buffer + sizeof(header), &seg1, sizeof(seg1));

    const mach_header_t *testHeader = (mach_header_t *)buffer;

    // Act
    const segment_command_t *result
        = sentrycrash_macho_getSegmentByNameFromHeader(testHeader, "__TEXT");

    // Assert
    XCTAssertNotEqual(result, NULL);
    XCTAssertEqual(strcmp(result->segname, "__TEXT"), 0);
}

- (void)testGetSegmentByNameFromHeader_DataSegment
{
    // Arrange

    // Create a test Mach-O header
    mach_header_t header;
    header.ncmds = 1;

    // Create a segment
    segment_command_t seg2;
    seg2.cmd = LC_SEGMENT_ARCH_DEPENDENT;
    seg2.cmdsize = sizeof(segment_command_t);
    strcpy(seg2.segname, "__DATA");

    // Copy the segment into the header memory
    uint8_t buffer[sizeof(header) + sizeof(seg2)];
    memcpy(buffer, &header, sizeof(header));
    memcpy(buffer + sizeof(header), &seg2, sizeof(seg2));

    const mach_header_t *testHeader = (mach_header_t *)buffer;

    // Act
    const segment_command_t *result
        = sentrycrash_macho_getSegmentByNameFromHeader(testHeader, "__DATA");

    // Assert
    XCTAssertNotEqual(result, NULL);
    XCTAssertEqual(strcmp(result->segname, "__DATA"), 0);
}

- (void)testGetSegmentByNameFromHeader_NotFound
{
    // Arrange

    // Create a test Mach-O header
    mach_header_t header;
    header.ncmds = 1;

    // Create a segment
    segment_command_t seg1;
    seg1.cmd = LC_SEGMENT_ARCH_DEPENDENT;
    seg1.cmdsize = sizeof(segment_command_t);
    strcpy(seg1.segname, "__TEXT");

    // Copy the segment into the header memory
    uint8_t buffer[sizeof(header) + sizeof(seg1)];
    memcpy(buffer, &header, sizeof(header));
    memcpy(buffer + sizeof(header), &seg1, sizeof(seg1));

    const mach_header_t *testHeader = (mach_header_t *)buffer;

    // Act
    const segment_command_t *result
        = sentrycrash_macho_getSegmentByNameFromHeader(testHeader, "__INVALID");

    // Assert
    XCTAssertEqual(result, NULL);
}

- (void)testGetSegmentByNameFromHeader_InvalidHeader
{
    // Arrange & Act
    const segment_command_t *result = sentrycrash_macho_getSegmentByNameFromHeader(NULL, "__TEXT");

    // Assert
    XCTAssertEqual(result, NULL);
}

- (void)testGetSegmentByNameFromHeader_InvalidSegment
{
    // Arrange
    // Create a test Mach-O header
    mach_header_t header;
    header.ncmds = 1;

    // Create a segment
    segment_command_t seg1;
    seg1.cmd = LC_SEGMENT_ARCH_DEPENDENT;
    seg1.cmdsize = sizeof(segment_command_t);
    strcpy(seg1.segname, "__TEXT");

    // Copy the segment into the header memory
    uint8_t buffer[sizeof(header) + sizeof(seg1)];
    memcpy(buffer, &header, sizeof(header));
    memcpy(buffer + sizeof(header), &seg1, sizeof(seg1));

    const mach_header_t *testHeader = (mach_header_t *)buffer;

    // Act
    const segment_command_t *result
        = sentrycrash_macho_getSegmentByNameFromHeader(testHeader, NULL);

    // Assert
    XCTAssertEqual(result, NULL);
}

- (void)testGetSectionByTypeFlagFromSegment_NonLazySymbolPointers
{
    // Arrange

    // Create a test segment
    segment_command_t segment;
    strcpy(segment.segname, "__DATA");
    segment.nsects = 1;

    // Create a section
    section_t sect1;
    strcpy(sect1.sectname, "__nl_symbol_ptr");
    sect1.flags = S_ATTR_PURE_INSTRUCTIONS | S_NON_LAZY_SYMBOL_POINTERS;

    // Copy the section into the segment memory
    uint8_t buffer[sizeof(segment) + sizeof(sect1)];
    memcpy(buffer, &segment, sizeof(segment));
    memcpy(buffer + sizeof(segment), &sect1, sizeof(sect1));

    const segment_command_t *testSegment = (segment_command_t *)buffer;

    // Act
    const section_t *result = sentrycrash_macho_getSectionByTypeFlagFromSegment(
        testSegment, S_NON_LAZY_SYMBOL_POINTERS);

    // Assert
    XCTAssertNotEqual(result, NULL);
    XCTAssertEqual(result->flags & SECTION_TYPE, S_NON_LAZY_SYMBOL_POINTERS);
    XCTAssertEqual(strcmp(result->sectname, "__nl_symbol_ptr"), 0);
}

- (void)testGetSectionByTypeFlagFromSegment_LazySymbolPointers
{
    // Arrange

    // Create a test segment
    segment_command_t segment;
    strcpy(segment.segname, "__DATA");
    segment.nsects = 1;

    // Create a section
    section_t sect2;
    strcpy(sect2.sectname, "__la_symbol_ptr");
    sect2.flags = S_ATTR_SOME_INSTRUCTIONS | S_LAZY_SYMBOL_POINTERS;

    // Copy the section into the segment memory
    uint8_t buffer[sizeof(segment) + sizeof(sect2)];
    memcpy(buffer, &segment, sizeof(segment));
    memcpy(buffer + sizeof(segment), &sect2, sizeof(sect2));

    const segment_command_t *testSegment = (segment_command_t *)buffer;

    // Act
    const section_t *result
        = sentrycrash_macho_getSectionByTypeFlagFromSegment(testSegment, S_LAZY_SYMBOL_POINTERS);

    // Assert
    XCTAssertNotEqual(result, NULL);
    XCTAssertEqual(result->flags & SECTION_TYPE, S_LAZY_SYMBOL_POINTERS);
    XCTAssertEqual(strcmp(result->sectname, "__la_symbol_ptr"), 0);
}

- (void)testGetSectionByTypeFlagFromSegment_Regular
{
    // Arrange
    // Create a test segment
    segment_command_t segment;
    strcpy(segment.segname, "__DATA");
    segment.nsects = 1;

    // Create a section
    section_t sect3;
    strcpy(sect3.sectname, "__const");
    sect3.flags = S_REGULAR;

    // Copy the section into the segment memory
    uint8_t buffer[sizeof(segment) + sizeof(sect3)];
    memcpy(buffer, &segment, sizeof(segment));
    memcpy(buffer + sizeof(segment), &sect3, sizeof(sect3));

    const segment_command_t *testSegment = (segment_command_t *)buffer;

    // Act
    const section_t *result
        = sentrycrash_macho_getSectionByTypeFlagFromSegment(testSegment, S_REGULAR);

    // Assert
    XCTAssertNotEqual(result, NULL);
    XCTAssertEqual(result->flags & SECTION_TYPE, S_REGULAR);
    XCTAssertEqual(strcmp(result->sectname, "__const"), 0);
}

- (void)testGetSectionByTypeFlagFromSegment_NotFound
{
    // Arrange

    // Create a test segment
    segment_command_t segment;
    strcpy(segment.segname, "__DATA");
    segment.nsects = 1;

    // Create a section
    section_t sect1;
    strcpy(sect1.sectname, "__nl_symbol_ptr");
    sect1.flags = S_ATTR_PURE_INSTRUCTIONS | S_NON_LAZY_SYMBOL_POINTERS;

    // Copy the section into the segment memory
    uint8_t buffer[sizeof(segment) + sizeof(sect1)];
    memcpy(buffer, &segment, sizeof(segment));
    memcpy(buffer + sizeof(segment), &sect1, sizeof(sect1));

    const segment_command_t *testSegment = (segment_command_t *)buffer;

    // Act
    const section_t *result
        = sentrycrash_macho_getSectionByTypeFlagFromSegment(testSegment, S_ATTR_DEBUG);

    // Assert
    // Verify that the section is not found for a different type flag
    XCTAssertEqual(result, NULL);
}

- (void)testGetSectionByTypeFlagFromSegment_InvalidSegment
{
    // Arrange & Act
    const section_t *result
        = sentrycrash_macho_getSectionByTypeFlagFromSegment(NULL, S_NON_LAZY_SYMBOL_POINTERS);

    // Assert
    XCTAssertEqual(result, NULL);
}

- (void)testGetSectionByTypeFlagFromSegment_InvalidFlag
{
    // Arrange

    // Create a test segment
    segment_command_t segment;
    strcpy(segment.segname, "__DATA");
    segment.nsects = 1;

    // Create a section
    section_t sect1;
    strcpy(sect1.sectname, "__nl_symbol_ptr");
    sect1.flags = S_ATTR_PURE_INSTRUCTIONS | S_NON_LAZY_SYMBOL_POINTERS;

    // Copy the section into the segment memory
    uint8_t buffer[sizeof(segment) + sizeof(sect1)];
    memcpy(buffer, &segment, sizeof(segment));
    memcpy(buffer + sizeof(segment), &sect1, sizeof(sect1));

    const segment_command_t *testSegment = (segment_command_t *)buffer;

    // Act
    // Use UINT32_MAX as the flag and ensure we're not crashing
    const section_t *result
        = sentrycrash_macho_getSectionByTypeFlagFromSegment(testSegment, UINT32_MAX);

    // Assert
    XCTAssertEqual(result, NULL);
}

- (void)testGetSectionProtection_ReadOnlyProtection
{
    // Arrange

    // Create a memory region with read-only protection
    vm_address_t address;
    vm_size_t size = getpagesize();
    vm_prot_t expectedProtection = VM_PROT_READ;
    kern_return_t result = vm_allocate(mach_task_self(), &address, size, VM_FLAGS_ANYWHERE);
    XCTAssertEqual(result, KERN_SUCCESS);

    result = vm_protect(mach_task_self(), address, size, FALSE, expectedProtection);
    XCTAssertEqual(result, KERN_SUCCESS);

    // Act
    vm_prot_t actualProtection = sentrycrash_macho_getSectionProtection((void *)address);

    // Assert
    XCTAssertEqual(actualProtection, expectedProtection);

    // Deallocate the memory region
    result = vm_deallocate(mach_task_self(), address, size);
    XCTAssertEqual(result, KERN_SUCCESS);
}

- (void)testGetSectionProtection_ExecutableProtection
{
    // Arrange

    // Create a memory region with executable protection
    vm_address_t address;
    vm_size_t size = getpagesize();
    vm_prot_t expectedProtection = VM_PROT_READ | VM_PROT_EXECUTE;
    kern_return_t result = vm_allocate(mach_task_self(), &address, size, VM_FLAGS_ANYWHERE);
    XCTAssertEqual(result, KERN_SUCCESS);

    result = vm_protect(mach_task_self(), address, size, FALSE, expectedProtection);
    XCTAssertEqual(result, KERN_SUCCESS);

    // Act
    vm_prot_t actualProtection = sentrycrash_macho_getSectionProtection((void *)address);

    // Assert
    XCTAssertEqual(actualProtection, expectedProtection);

    // Deallocate the memory region
    result = vm_deallocate(mach_task_self(), address, size);
    XCTAssertEqual(result, KERN_SUCCESS);
}

- (void)testGetSectionProtection_NoAccessProtection
{
    // Arrange

    // Create a memory region with no access protection
    vm_address_t address;
    vm_size_t size = getpagesize();
    vm_prot_t expectedProtection = VM_PROT_NONE;
    kern_return_t result = vm_allocate(mach_task_self(), &address, size, VM_FLAGS_ANYWHERE);
    XCTAssertEqual(result, KERN_SUCCESS);

    result = vm_protect(mach_task_self(), address, size, FALSE, expectedProtection);
    XCTAssertEqual(result, KERN_SUCCESS);

    // Act
    vm_prot_t actualProtection = sentrycrash_macho_getSectionProtection((void *)address);

    // Assert
    XCTAssertEqual(actualProtection, expectedProtection);

    // Deallocate the memory region
    result = vm_deallocate(mach_task_self(), address, size);
    XCTAssertEqual(result, KERN_SUCCESS);
}

- (void)testGetSectionProtection_WithInvalidMemoryAddress_ReturnsDefaultProtection
{
    // Arrange
    vm_address_t invalidAddress = 0xFFFFFFFFFFFFFFFFULL;

    // Act
    vm_prot_t actualProtection = sentrycrash_macho_getSectionProtection((void *)invalidAddress);

    // Assert
    XCTAssertEqual(
        actualProtection, VM_PROT_READ, @"Expected default protection value of VM_PROT_READ");
}

- (void)testGetSectionProtection_PassingNULL_ReturnsDefaultProtection
{
    // Arrange
    vm_prot_t expectedProtection = VM_PROT_READ | VM_PROT_EXECUTE;

    // Act
    vm_prot_t actualProtection = sentrycrash_macho_getSectionProtection((void *)NULL);

    // Assert
    XCTAssertEqual(actualProtection, expectedProtection,
        @"Expected default protection value of VM_PROT_READ | VM_PROT_EXECUTE");
}

@end
