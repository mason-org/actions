#!/usr/bin/env bash

if [[ -n $RUNNER_DEBUG ]]; then
    set -x
fi

set -euo pipefail

npm install -g ajv ajv-cli ajv-formats

SCHEMA_FILE=$(mktemp -t XXXX.json)
curl -fsSL https://github.com/mason-org/registry-schema/releases/latest/download/package.schema.json > "$SCHEMA_FILE"
<<< "$PACKAGES" tr ' ' '\n' | xargs -P10 -I{} ajv validate -d {} -c ajv-formats -s "$SCHEMA_FILE"
