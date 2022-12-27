#!/usr/bin/env bash

if [[ -n $RUNNER_DEBUG ]]; then
    set -x
fi

set -euo pipefail

SKIPPED_PACKAGES=()

function skip_package {
    echo "Skipping package $1"
    SKIPPED_PACKAGES+=("$1")
}

function skip_packages {
    for pkg in "$@"; do
        skip_package "$pkg"
    done
}

function is-testing-package {
    local pkg=$1
    for PKG in $PACKAGES; do
        if [[ $PKG == "$pkg" ]]; then
            return 0
        fi
    done
    return 1
}

function match {
    local fn=$1
    shift
    for pkg in "$@"; do
        if is-testing-package "$pkg"; then
            EXIT_CODE=0
            echo "Running $fn"
            "$fn" || EXIT_CODE=$?
            case "$EXIT_CODE" in
                0)
                    return 0
                    ;;
                2)
                    skip_packages "$@"
                    return 0
                    ;;
                *)
                    echo >&2 "Failed to run ${fn}"
                    return 1
                    ;;
            esac
        fi
    done
    return 0
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
    if [[ $RUNNER_OS == macOS ]]; then
        brew install erlang rebar3
        return 0
    else
        echo "setup_beam=true" >> "$GITHUB_OUTPUT"
        return 0
    fi
}

function install-opam {
    if [[ $RUNNER_OS == macOS ]]; then
        brew install opam
        opam init
        return 0
    elif [[ $RUNNER_OS == Linux ]]; then
        sudo add-apt-repository -y ppa:avsm/ppa
        sudo apt install -y opam
        opam init
        return 0
    elif [[ $RUNNER_OS == Windows ]]; then
        # Opam support via Chocolatey planned for 2.2
        return 2
    fi
    return 1
}

function install-nim {
    echo "setup_nim=true" >> "$GITHUB_OUTPUT"
    return 0
}

function install-nix {
    if [[ $RUNNER_OS == Windows ]]; then
        return 2
    fi
    echo "setup_nix=true" >> "$GITHUB_OUTPUT"
    return 0
}

if [[ $RUNNER_OS == Linux ]]; then
    sudo apt update
fi

install-yq

match install-erlang "packages/erlang-ls/package.yaml"
match install-opam "packages/ocaml-lsp/package.yaml"
match install-nim "packages/nimlsp/package.yaml"
match install-nix "packages/nil/package.yaml"

echo "SKIPPED_PACKAGES=${SKIPPED_PACKAGES[@]+"${SKIPPED_PACKAGES[@]}"}" >> "$GITHUB_ENV"

PACKAGES_TO_TEST=""

set +u

for pkg in $PACKAGES; do
    if [[ ! " ${SKIPPED_PACKAGES[*]} " =~ " ${pkg} " ]]; then
        PACKAGES_TO_TEST="$pkg $PACKAGES_TO_TEST"
    fi
done

echo "PACKAGES=$PACKAGES_TO_TEST" >> "$GITHUB_OUTPUT"

# vim:sw=4:et
