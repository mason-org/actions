#!/usr/bin/env bash

set -euo pipefail

function is-testing-package() {
    for pkg in "$@"; do
        for PKG in "${PACKAGES[@]}"; do
            if [[ $PKG == "packages/$pkg/package.yaml" ]]; then
                return 0
            fi
        done
    done
    return 1
}

function install-yq() {
    if [[ $RUNNER_OS == macOS ]]; then
        if [[ $RUNNER_ARCH == X64 ]]; then
            sudo curl -fL "https://github.com/mikefarah/yq/releases/download/v4.30.6/yq_darwin_amd64" -o /usr/local/bin/yq
            sudo chmod +x /usr/local/bin/yq
            return 0
        elif [[ $RUNNER_ARCH == ARM64 ]]; then
            sudo curl -f "https://github.com/mikefarah/yq/releases/download/v4.30.6/yq_darwin_arm64" -o /usr/local/bin/yq
            sudo chmod +x /usr/local/bin/yq
            return 0
        fi
    elif [[ $RUNNER_OS == Linux ]]; then
        if [[ $RUNNER_ARCH == X64 ]]; then
            sudo curl -f "https://github.com/mikefarah/yq/releases/download/v4.30.6/yq_linux_amd64" -o /usr/local/bin/yq
            sudo chmod +x /usr/local/bin/yq
            return 0
        elif [[ $RUNNER_ARCH == ARM64 ]]; then
            sudo curl -f "https://github.com/mikefarah/yq/releases/download/v4.30.6/yq_linux_arm64" -o /usr/local/bin/yq
            sudo chmod +x /usr/local/bin/yq
            return 0
        fi
    elif [[ $RUNNER_OS == Windows ]]; then
        if [[ $RUNNER_ARCH == X64 ]]; then
            curl -f "https://github.com/mikefarah/yq/releases/download/v4.30.6/yq_windows_amd64.exe" > /c/ProgramData/chocolatey/bin/yq.exe
            return 0
        fi
    fi
    >&2 echo "Unable to find yq download url for ${RUNNER_OS}_$RUNNER_ARCH"
    return 1
}

function install-erlang() {
    echo "Installing erlang!"
    if [[ $RUNNER_OS == macOS ]]; then
        brew install erlang rebar3
    elif [[ $RUNNER_OS == Linux ]]; then
        curl -f https://s3.amazonaws.com/rebar3/rebar3 >/usr/local/bin/rebar3
        chmod +x /usr/local/bin/rebar3
        sudo apt-get install -y erlang
    elif [[ $RUNNER_OS == Windows ]]; then
        choco install erlang
        # We repurpose chocolatey's bin directory because we're lazy.
        curl -f https://s3.amazonaws.com/rebar3/rebar3 >/c/ProgramData/chocolatey/bin/rebar3
        cat <<EOF >"/c/ProgramData/chocolatey/bin/rebar3.cmd"
@echo off
setlocal
set rebarscript=%~f0
escript.exe "%rebarscript:.cmd=%" %*
EOF
    fi
}

install-yq

if is-testing-package "erlang-ls"; then
    install-erlang
fi

# vim:sw=4:et
