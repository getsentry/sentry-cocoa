/**
 * markdownlint custom rule: changelog-no-duplicate-sections
 *
 * Flags sibling headings that repeat the same text, which is how changelog
 * files get corrupted when a second ### Features (or similar) block is added
 * under ## Unreleased or a version heading. Headings with different parents
 * may repeat, so ### Features under 1.0.0 and 2.0.0 is allowed.
 *
 * This is MD024/siblings_only with a parent-aware message. Built-in rules stay
 * disabled so the rest of the changelog's historical style is left alone.
 */

"use strict";

/**
 * @param {string[]} lines
 * @returns {{ lineNumber: number, detail: string, context: string }[]}
 */
function findDuplicateSiblingHeadings(lines) {
    const errors = [];
    const knownContents = [null, []];
    const titles = [null, ""];
    let lastLevel = 1;
    let inFence = false;

    lines.forEach((line, index) => {
        const trimmed = line.trim();
        if (trimmed.startsWith("```")) {
            inFence = !inFence;
            return;
        }
        if (inFence) {
            return;
        }

        const match = /^(#{1,6}) (.+)$/.exec(line);
        if (!match) {
            return;
        }

        const level = match[1].length;
        const text = match[2].trim();
        const lineNumber = index + 1;

        while (lastLevel < level) {
            lastLevel += 1;
            knownContents[lastLevel] = [];
            titles[lastLevel] = "";
        }
        while (lastLevel > level) {
            knownContents[lastLevel] = [];
            titles[lastLevel] = "";
            lastLevel -= 1;
        }

        const known = knownContents[level];
        if (known.includes(text)) {
            const parent = titles[level - 1];
            const detail = parent
                ? `Duplicate "${text}" heading under "${parent}"`
                : `Duplicate "${text}" heading`;
            errors.push({
                lineNumber,
                detail,
                context: `${"#".repeat(level)} ${text}`
            });
        } else {
            known.push(text);
        }
        titles[level] = text;
    });

    return errors;
}

/** @type {import("markdownlint").Rule} */
const rule = {
    names: ["changelog-no-duplicate-sections"],
    description:
        "Changelog version blocks must not repeat the same section heading",
    tags: ["changelog", "headings"],
    parser: "none",
    function: (params, onError) => {
        for (const error of findDuplicateSiblingHeadings(params.lines)) {
            onError(error);
        }
    }
};

rule.findDuplicateSiblingHeadings = findDuplicateSiblingHeadings;

module.exports = rule;
