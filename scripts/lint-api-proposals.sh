#!/usr/bin/env bash
# =============================================================================
# API Proposal Linter
#
# Validates API proposal Markdown files against a set of quality checks.
#
# Usage:
#   lint-api-proposals.sh <file> [file ...]
#
# Checks performed:
#   0. Files with a 0000- prefix are not allowed in subdirectories.
#   1. No HTML comments (<!-- / -->) left in the document.
#   2. No un-replaced template placeholders (REPLACE_WITH_...).
#   3. The required pre-requisite checkbox is checked ([x]).
# =============================================================================
set -euo pipefail

if [[ $# -eq 0 ]]; then
    echo "No API proposal files found to lint."
    exit 0
fi

failed=0

for file in "$@"; do
    basename=$(basename "$file")
    dirpart=$(dirname "$file")

    # Check 0: 0000-* prefix files are only allowed in the top-level api/ directory.
    # Determine the absolute api/ directory based on the script location so that
    # behavior is independent of the caller's current working directory.
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    api_dir="$(cd "$script_dir/../api" && pwd)"
    normalized_dir=$(cd "$dirpart" 2>/dev/null && pwd) || normalized_dir="$dirpart"
    if [[ "$basename" == 0000-* && "$normalized_dir" != "$api_dir" ]]; then
        printf "  ERROR: Files with a 0000- prefix are not allowed in subdirectories. Move to the top-level api/ folder or rename the file.\n"
        echo ""
        failed=1
        continue
    fi

    # Skip template files (0000-*) in the top-level directory.
    if [[ "$basename" == 0000-* ]]; then
        echo "SKIP: $file (template)"
        continue
    fi

    # Skip README files — they are not proposals.
    if [[ "$basename" == "README.md" ]]; then
        echo "SKIP: $file (README)"
        continue
    fi

    errors=""

    # Check 1: HTML comments must be removed before submission.
    if grep -qn -- '<!--' "$file" || grep -qn -- '-->' "$file"; then
        lines=$(grep -n -- '<!--\|-->' "$file" | head -5)
        errors="${errors}\n  ERROR: File contains HTML comments that must be removed:\n${lines}"
    fi

    # Check 2: All REPLACE_WITH_ placeholders must be filled in.
    if grep -qn 'REPLACE_WITH_' "$file"; then
        lines=$(grep -n 'REPLACE_WITH_' "$file" | head -5)
        errors="${errors}\n  ERROR: File contains un-replaced template placeholders (REPLACE_WITH_...):\n${lines}"
    fi

    # Check 3: Pre-requisite checkbox must be checked.
    if ! grep -q '\[x\] This API is a preview API, OR it is a GA API' "$file"; then
        errors="${errors}\n  ERROR: Pre-requisite checkbox is not checked. Expected '[x] This API is a preview API, OR it is a GA API'."
    fi

    # Report results for this file.
    if [[ -n "$errors" ]]; then
        echo "FAIL: $file"
        printf "%b\n" "$errors"
        echo ""
        failed=1
    else
        echo "OK:   $file"
    fi
done

# Summary.
if [[ "$failed" -ne 0 ]]; then
    echo "Lint failed."
    exit 1
else
    echo "All files passed lint."
fi
