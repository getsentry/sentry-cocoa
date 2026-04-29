#!/bin/bash
set -euo pipefail

# Extract public API declarations from SentryObjC headers for stability tracking.
#
# Uses clang AST parsing to reliably extract Objective-C declarations.
# Outputs a sorted JSON array of declaration objects. Used by update-api.sh
# to generate sdk_api_objc.json. Changes to the output indicate API changes.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HEADERS_DIR="$PROJECT_ROOT/Sources/SentryObjC/Public"
TYPES_HEADERS_DIR="$PROJECT_ROOT/Sources/SentryObjCTypes/Public"
SENTRY_HEADERS_DIR="$PROJECT_ROOT/Sources/Sentry/Public"
UMBRELLA_HEADER="$HEADERS_DIR/SentryObjC.h"

# Temporary files
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

AST_JSON="$TMP_DIR/ast.json"
INTERFACES_JSON="$TMP_DIR/interfaces.json"
PROTOCOLS_JSON="$TMP_DIR/protocols.json"
METHODS_JSON="$TMP_DIR/methods.json"
PROPERTIES_JSON="$TMP_DIR/properties.json"
TYPEDEFS_JSON="$TMP_DIR/typedefs.json"

# Get iOS SDK path
SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)

# Step 1: Generate AST dump from umbrella header.
# SentryObjC's umbrella uses `__has_include(<...>)` blocks to import headers
# from Sentry / SentryObjCTypes when those frameworks are available, falling
# back to bare-quote imports otherwise. In this clang-only context (no frame-
# work search paths), the angle-bracket branches fail to resolve, so we add
# all three public-header directories to the -I path so the quoted fallbacks
# resolve directly.
xcrun clang -x objective-c \
  -Xclang -ast-dump=json \
  -fsyntax-only \
  -isysroot "$SDK_PATH" \
  -I "$HEADERS_DIR" \
  -I "$TYPES_HEADERS_DIR" \
  -I "$SENTRY_HEADERS_DIR" \
  "$UMBRELLA_HEADER" \
  2>/dev/null > "$AST_JSON"

# Step 2: Extract interfaces
jq '
  [.. | objects |
   select(.kind == "ObjCInterfaceDecl") |
   select(.loc.file? // "" | contains("SentryObjC") or contains("/Sentry/Public/")) |
   {
     kind,
     name,
     file: (.loc.file | split("/") | last),
     super: .super.name?,
     has_inner: (if .inner then true else false end)
   }]
' "$AST_JSON" > "$INTERFACES_JSON"

# Step 3: Extract protocols
jq '
  [.. | objects |
   select(.kind == "ObjCProtocolDecl") |
   select(.loc.file? // "" | contains("SentryObjC") or contains("/Sentry/Public/")) |
   {
     kind,
     name,
     file: (.loc.file | split("/") | last)
   }]
' "$AST_JSON" > "$PROTOCOLS_JSON"

# Step 4: Extract methods (from interfaces)
jq '
  [.. | objects |
   select(.kind == "ObjCInterfaceDecl") |
   select(.loc.file? // "" | contains("SentryObjC") or contains("/Sentry/Public/")) |
   select(.inner) |
   . as $interface |
   .inner[] |
   select(.kind == "ObjCMethodDecl") |
   {
     kind,
     name,
     file: ($interface.loc.file | split("/") | last),
     returnType: .returnType.qualType?,
     instance: .instance?
   }]
' "$AST_JSON" > "$METHODS_JSON"

# Step 5: Extract properties (from interfaces)
jq '
  [.. | objects |
   select(.kind == "ObjCInterfaceDecl") |
   select(.loc.file? // "" | contains("SentryObjC") or contains("/Sentry/Public/")) |
   select(.inner) |
   . as $interface |
   .inner[] |
   select(.kind == "ObjCPropertyDecl") |
   {
     kind,
     name,
     file: ($interface.loc.file | split("/") | last),
     type: .type.qualType?
   }]
' "$AST_JSON" > "$PROPERTIES_JSON"

# Step 6: Extract typedefs
jq '
  [.. | objects |
   select(.kind == "TypedefDecl") |
   select(.loc.file? // "" | contains("SentryObjC") or contains("/Sentry/Public/")) |
   {
     kind,
     name,
     file: (.loc.file | split("/") | last),
     type: .type.qualType?
   }]
' "$AST_JSON" > "$TYPEDEFS_JSON"

# Step 7: Combine all declarations and output
jq -s 'add | sort_by(.file, .kind, .name)' \
  "$INTERFACES_JSON" \
  "$PROTOCOLS_JSON" \
  "$METHODS_JSON" \
  "$PROPERTIES_JSON" \
  "$TYPEDEFS_JSON"
