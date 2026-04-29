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

# Get iOS SDK path
SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)

# Step 1: Generate AST dump from umbrella header.
xcrun clang -x objective-c \
  -Xclang -ast-dump=json \
  -fsyntax-only \
  -isysroot "$SDK_PATH" \
  -I "$HEADERS_DIR" \
  -I "$TYPES_HEADERS_DIR" \
  -I "$SENTRY_HEADERS_DIR" \
  "$UMBRELLA_HEADER" \
  2>/dev/null > "$AST_JSON"

# Step 2: Extract declarations.
#
# We filter by name prefix ("Sentry"/"PrivateSentry") rather than source
# file path because clang's AST JSON omits loc.file when it hasn't changed
# from the previous node, making file-based filtering unreliable.
#
# Clang emits multiple ObjCInterfaceDecl nodes for the same class (forward
# declarations + the full definition). We deduplicate by collecting all
# members across all nodes sharing the same name and emitting each
# interface/protocol only once.
jq '
  def is_sentry: startswith("Sentry") or startswith("PrivateSentry");

  # Collect all interface nodes grouped by name, merge their members
  (
    [.inner[] |
      select(.kind == "ObjCInterfaceDecl" and (.name // "" | is_sentry))
    ] | group_by(.name) | map(
      (.[0].name) as $name |
      (map(select(.super.name?)) | first // null) as $super_node |
      (map(select(.inner) | .inner[]) | map(
        select(.kind == "ObjCMethodDecl" or .kind == "ObjCPropertyDecl")
      )) as $members |
      {
        name: $name,
        super: ($super_node // {} | .super.name? // null),
        members: ($members | unique_by(.kind, .name))
      }
    )
  ) as $interfaces |

  # Collect all protocol nodes grouped by name
  (
    [.inner[] |
      select(.kind == "ObjCProtocolDecl" and (.name // "" | is_sentry))
    ] | group_by(.name) | map(
      (.[0].name) as $name |
      (map(select(.inner) | .inner[]) | map(
        select(.kind == "ObjCMethodDecl" or .kind == "ObjCPropertyDecl")
      )) as $members |
      {
        name: $name,
        members: ($members | unique_by(.kind, .name))
      }
    )
  ) as $protocols |

  # Collect typedefs
  (
    [.inner[] |
      select(.kind == "TypedefDecl" and (.name // "" | is_sentry))
    ] | unique_by(.name)
  ) as $typedefs |

  # Collect enums
  (
    [.inner[] |
      select(.kind == "EnumDecl" and (.name // "" | is_sentry))
    ] | group_by(.name) | map(
      (.[0].name) as $name |
      (map(select(.inner) | .inner[]) | map(
        select(.kind == "EnumConstantDecl")
      )) as $constants |
      {name: $name, constants: ($constants | unique_by(.name))}
    )
  ) as $enums |

  # Emit everything as a flat sorted array
  [
    # Interfaces + their members
    ($interfaces[] | (
      {kind: "ObjCInterfaceDecl", name, super, has_inner: ((.members | length) > 0)},
      (.name as $p | .members[] |
        if .kind == "ObjCMethodDecl" then
          {kind, name, parent: $p, returnType: .returnType.qualType?, instance: .instance?}
        else
          {kind, name, parent: $p, type: .type.qualType?}
        end
      )
    )),

    # Protocols + their members
    ($protocols[] | (
      {kind: "ObjCProtocolDecl", name},
      (.name as $p | .members[] |
        if .kind == "ObjCMethodDecl" then
          {kind, name, parent: $p, returnType: .returnType.qualType?, instance: .instance?}
        else
          {kind, name, parent: $p, type: .type.qualType?}
        end
      )
    )),

    # Typedefs
    ($typedefs[] | {kind, name, type: .type.qualType?}),

    # Enums + their constants
    ($enums[] | (
      {kind: "EnumDecl", name},
      (.name as $p | .constants[] | {kind, name, parent: $p})
    ))

  ] | sort_by(.kind, .name)
' "$AST_JSON"
