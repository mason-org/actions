#!/usr/bin/env bash

if [[ -n $RUNNER_DEBUG ]]; then
    set -x
fi

set -euo pipefail

SKIPPED_PACKAGES=()

function skip_package {
    SKIPPED_PACKAGES+=("$1")
}

function is-testing-package {
    for pkg in "$@"; do
        for PKG in "${PACKAGES[@]}"; do
            if [[ $PKG == $pkg ]]; then
                return 0
            fi
        done
    done
    return 1
}

function install-yq {
    echo "Installing yq!"
    if [[ $RUNNER_OS == macOS ]]; then
        if [[ $RUNNER_ARCH == X64 ]]; then
            sudo curl -fL "https://github.com/mikefarah/yq/releases/download/v4.30.6/yq_darwin_amd64" -o /usr/local/bin/yq
            sudo chmod +x /usr/local/bin/yq
            return 0
        elif [[ $RUNNER_ARCH == ARM64 ]]; then
            sudo curl -fL "https://github.com/mikefarah/yq/releases/download/v4.30.6/yq_darwin_arm64" -o /usr/local/bin/yq
            sudo chmod +x /usr/local/bin/yq
            return 0
        fi
    elif [[ $RUNNER_OS == Linux ]]; then
        if [[ $RUNNER_ARCH == X64 ]]; then
            sudo curl -fL "https://github.com/mikefarah/yq/releases/download/v4.30.6/yq_linux_amd64" -o /usr/local/bin/yq
            sudo chmod +x /usr/local/bin/yq
            return 0
        elif [[ $RUNNER_ARCH == ARM64 ]]; then
            sudo curl -fL "https://github.com/mikefarah/yq/releases/download/v4.30.6/yq_linux_arm64" -o /usr/local/bin/yq
            sudo chmod +x /usr/local/bin/yq
            return 0
        fi
    elif [[ $RUNNER_OS == Windows ]]; then
        if [[ $RUNNER_ARCH == X64 ]]; then
            curl -fL "https://github.com/mikefarah/yq/releases/download/v4.30.6/yq_windows_amd64.exe" -o /c/ProgramData/chocolatey/bin/yq.exe
            return 0
        fi
    fi
    >&2 echo "Unable to find yq download url for ${RUNNER_OS}_$RUNNER_ARCH"
    return 1
}

function install-erlang {
    echo "Installing erlang!"
    if [[ $RUNNER_OS == macOS ]]; then
        brew install erlang rebar3
    elif [[ $RUNNER_OS == Linux ]]; then
        sudo curl -f https://s3.amazonaws.com/rebar3/rebar3 >/usr/local/bin/rebar3
        sudo chmod +x /usr/local/bin/rebar3
        sudo apt install -y erlang
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

function install-opam {
    echo "Installing opam!"
    if [[ $RUNNER_OS == macOS ]]; then
        brew install opam
        sudo opam init
    elif [[ $RUNNER_OS == Linux ]]; then
        sudo add-apt-repository -y ppa:avsm/ppa
        sudo apt install -y opam
        opam init
    elif [[ $RUNNER_OS == Windows ]]; then
        # Opam support via Chocolatey planned for 2.2
        skip_package "packages/ocaml-lsp/package.yaml"
    fi
}

function install-nim {
    echo "Installing nim!"
    if [[ $RUNNER_OS == macOS ]]; then
        brew install nim
    elif [[ $RUNNER_OS == Linux ]]; then
        # Not packaged for Ubuntu 22.04.
        skip_package "packages/nimlsp/package.yaml"
    elif [[ $RUNNER_OS == Windows ]]; then
        choco install choosenim
        choosenim -y stable
    fi
}

if [[ $RUNNER_OS == Linux ]]; then
    sudo apt update
fi

install-yq

if is-testing-package "packages/erlang-ls/package.yaml"; then
    install-erlang
fi

if is-testing-package "packages/ocaml-lsp/package.yaml"; then
    install-opam
fi

if is-testing-package "packages/nimlsp/package.yaml"; then
    install-nim
fi

echo "SKIPPED_PACKAGES=${SKIPPED_PACKAGES[@]+"${SKIPPED_PACKAGES[@]}"}" >> "$GITHUB_ENV"

# vim:sw=4:et
