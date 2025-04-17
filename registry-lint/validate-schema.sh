#!/usr/bin/env bash

if [[ -n $RUNNER_DEBUG ]]; then
    set -x
fi

set -euo pipefail

SCHEMA_FILE=$(mktemp -t XXXX.json)
curl -fsSL https://github.com/mason-org/registry-schema/releases/latest/download/package.schema.json > "$SCHEMA_FILE"
<<< "$PACKAGES" tr ' ' '\n' | xargs -P10 -I{} jv -d 7 "$SCHEMA_FILE" {}

for pkg in $PACKAGES; do
    # Check if CRLF characters exist in the file
    if grep -q $'\x0D' "$pkg"; then
        >&2 echo "::error file=$pkg::CRLF characters detected in the file."
        exit 1
    fi

    # Ensure that the directory name corresponds with the package name
    pkg_name=$(sed -nE 's/name: (.+)$/\1/p' "$pkg")
    if [[ "$pkg" != "packages/${pkg_name}/package.yaml" ]]; then
        >&2 echo "::error file=$pkg::Package name ($pkg_name) doesn't match directory name (${pkg%/*})."
        exit 1
    else
        echo "$pkg has valid package name $pkg_name"
    fi
done
