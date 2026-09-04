"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");
const {
    findDuplicateSiblingHeadings
} = require("./changelog-no-duplicate-sections.cjs");

function lines(markdown) {
    return markdown.replace(/^\n/, "").replace(/\n$/, "").split("\n");
}

test("allows the same section name under different version headings", () => {
    const errors = findDuplicateSiblingHeadings(
        lines(`
# Changelog

## Unreleased

### Features

- New API

## 1.0.0

### Features

- Old API
`)
    );
    assert.deepEqual(errors, []);
});

test("flags a second Features block under Unreleased", () => {
    const errors = findDuplicateSiblingHeadings(
        lines(`
# Changelog

## Unreleased

### Features

- First

### Improvements

- Polish

### Features

- Second
`)
    );
    assert.equal(errors.length, 1);
    assert.equal(errors[0].lineNumber, 13);
    assert.equal(
        errors[0].detail,
        'Duplicate "Features" heading under "Unreleased"'
    );
    assert.equal(errors[0].context, "### Features");
});

test("flags a second Features block under a version heading", () => {
    const errors = findDuplicateSiblingHeadings(
        lines(`
## 9.20.0

### Fixes

- First fix

### Features

- A feature

### Fixes

- Second fix
`)
    );
    assert.equal(errors.length, 1);
    assert.equal(errors[0].lineNumber, 11);
    assert.equal(errors[0].detail, 'Duplicate "Fixes" heading under "9.20.0"');
});

test("flags duplicate Unreleased headings", () => {
    const errors = findDuplicateSiblingHeadings(
        lines(`
# Changelog

## Unreleased

### Features

## Unreleased

### Fixes
`)
    );
    assert.equal(errors.length, 1);
    assert.equal(errors[0].lineNumber, 7);
    assert.equal(
        errors[0].detail,
        'Duplicate "Unreleased" heading under "Changelog"'
    );
});

test("ignores headings inside fenced code blocks", () => {
    const errors = findDuplicateSiblingHeadings(
        lines(`
## Unreleased

### Features

\`\`\`
### Features
\`\`\`

### Fixes
`)
    );
    assert.deepEqual(errors, []);
});

test("returns no errors for a file without headings", () => {
    assert.deepEqual(findDuplicateSiblingHeadings(["just some text"]), []);
});
