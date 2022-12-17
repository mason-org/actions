#!/usr/bin/env bash

set -euo pipefail

function is_testing_package() {
    for pkg in "$@"; do
        for PKG in "${PACKAGES[@]}"; do
            if [[ $PKG == "packages/$pkg/package.yaml" ]]; then
                return 0;
            fi
        done
    done
    return 1;
}

function install_erlang() {
    echo "Installing erlang!"
    if [[ $RUNNER_OS == macOS ]]; then
        brew install erlang rebar3
    elif [[ $RUNNER_OS == Linux ]]; then
        curl -f https://s3.amazonaws.com/rebar3/rebar3 > /usr/local/bin/rebar3
        chmod +x /usr/local/bin/rebar3
        sudo apt-get install -y erlang
    elif [[ $RUNNER_OS == Windows ]]; then
        choco install erlang
        # We repurpose chocolatey's bin directory because we're lazy.
        curl -f https://s3.amazonaws.com/rebar3/rebar3 > /c/ProgramData/chocolatey/bin/rebar3
        cat <<EOF > "/c/ProgramData/chocolatey/bin/rebar3.cmd"
@echo off
setlocal
set rebarscript=%~f0
escript.exe "%rebarscript:.cmd=%" %*
EOF
    fi
}

if is_testing_package "erlang-ls"; then
    install_erlang
fi

# vim:sw=4:et
