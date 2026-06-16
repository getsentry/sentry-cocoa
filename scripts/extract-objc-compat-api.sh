#!/bin/bash
set -euo pipefail

# Extract ObjC-visible API from the SentryObjCCompat Swift wrappers.
#
# Builds SentryObjCCompat, then parses the compiler-generated -Swift.h
# header with clang AST to extract all ObjC declarations. Output format
# matches extract-objc-api.sh (flat sorted JSON array) so the two can
# be compared for drift detection.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

OUTPUT=""
CONFIGURATION="Release"

usage() {
    log_notice "Usage: $0"
    log_notice "  --output <path>            Output JSON file path (required)"
    log_notice "  --configuration <name>     Xcode build configuration (default: Release)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --output)        OUTPUT="$2";        shift 2 ;;
        --configuration) CONFIGURATION="$2"; shift 2 ;;
        *)               usage ;;
    esac
done

if [ -z "$OUTPUT" ]; then
    log_error "Error: --output is required"
    usage
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

BUILD_DIR="$TMP_DIR/build"
INTERMEDIATES_DIR="$TMP_DIR/intermediates"
AST_JSON="$TMP_DIR/ast.json"

# Step 1: Build SentryObjCCompat to generate the -Swift.h header.
log_info "Building SentryObjCCompat framework (configuration: $CONFIGURATION)"
xcodebuild build \
    -project "$PROJECT_ROOT/Sentry.xcodeproj" \
    -scheme SentryObjCCompat \
    -configuration "$CONFIGURATION" \
    -sdk iphoneos \
    -arch arm64 \
    CODE_SIGNING_ALLOWED=NO \
    ONLY_ACTIVE_ARCH=YES \
    SYMROOT="$BUILD_DIR" \
    OBJROOT="$INTERMEDIATES_DIR" \
    >/dev/null 2>&1

# Step 2: Locate the generated header.
SWIFT_HEADER="$INTERMEDIATES_DIR/Sentry.build/$CONFIGURATION-iphoneos/SentryObjCCompat.build/DerivedSources/SentryObjCCompat-Swift.h"
if [ ! -f "$SWIFT_HEADER" ]; then
    log_error "SentryObjCCompat-Swift.h not found at expected path"
    log_error "looked in: $SWIFT_HEADER"
    exit 1
fi

# Step 3: Parse with clang AST dump.
log_info "Generating clang AST from SentryObjCCompat-Swift.h"
SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)

xcrun clang -x objective-c \
    -Xclang -ast-dump=json \
    -fsyntax-only \
    -isysroot "$SDK_PATH" \
    "$SWIFT_HEADER" \
    2>/dev/null > "$AST_JSON"

# Step 4: Extract declarations using the same approach as extract-objc-api.sh.
#
# Filter by SentryObjC prefix. Deduplicate interfaces that appear multiple
# times (forward declarations + full definition).
log_info "Extracting declarations from AST"
jq '
  def is_sentry: startswith("SentryObjC");

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
' "$AST_JSON" > "$OUTPUT"

log_info "SentryObjCCompat API written to $OUTPUT"
