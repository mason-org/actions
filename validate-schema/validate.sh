#!/usr/bin/env bash

if [[ -n $RUNNER_DEBUG ]]; then
    set -x
fi

set -euo pipefail

npm install -g ajv ajv-cli ajv-formats

<<< "$PACKAGES" tr ' ' '\n' | xargs -P10 -I{} ajv validate -d {} --spec=draft2020 -c ajv-formats -s schemas/package.schema.json -r 'schemas/{components,enums}/**/*.json'

for pkg in $PACKAGES; do
    pkg_name=$(sed -nE 's/name: (.+)$/\1/p' "$pkg")
    if [[ "$pkg" != "packages/${pkg_name}/package.yaml" ]]; then
        >&2 echo "$pkg_name name doesn't match directory name ($pkg)."
        exit 1
    else
        echo "$pkg has valid package name $pkg_name"
    fi
done
