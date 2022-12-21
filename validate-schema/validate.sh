#!/usr/bin/env bash

if [[ -n $RUNNER_DEBUG ]]; then
    set -x
fi

set -euo pipefail

npm install -g ajv ajv-cli ajv-formats

xargs -n1 -I{} ajv validate -d {} --spec=draft2020 -c ajv-formats -s schemas/package.schema.json -r 'schemas/{components,enums}/**/*.json' <<< "$PACKAGES"
