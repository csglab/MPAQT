#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SMOKE_ROOT="${MPAQT_INSTALL_SMOKE_ROOT:-${TMPDIR:-/tmp}/mpaqt-install-smoke}"
RECREATE_ENVS="${RECREATE_ENVS:-0}"

log() {
    printf '[install-smoke] %s\n' "$*"
}

fail() {
    printf '[install-smoke] ERROR: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 ||
        fail "required command not found: $1"
}

reset_case_dir() {
    local name="$1"
    local case_dir="$SMOKE_ROOT/$name"

    case "$case_dir" in
        "$SMOKE_ROOT"/*) ;;
        *) fail "refusing to reset unsafe directory: $case_dir" ;;
    esac

    rm -rf "$case_dir"
    mkdir -p "$case_dir"
    printf '%s\n' "$case_dir"
}

conda_env_exists() {
    local env_name="$1"

    conda env list |
        awk 'NF > 0 && $1 !~ /^#/ {print $1}' |
        grep -Fxq "$env_name"
}

prepare_conda_env_name() {
    local env_name="$1"

    if ! conda_env_exists "$env_name"; then
        return 0
    fi

    if [[ "$RECREATE_ENVS" == "1" ]]; then
        log "Removing existing Conda environment: $env_name"
        conda env remove -n "$env_name" -y
        return 0
    fi

    fail "Conda environment '$env_name' already exists. Re-run with RECREATE_ENVS=1 to replace it."
}

create_toy_reference() {
    local case_dir="$1"
    "$SCRIPT_DIR/create-toy-reference.sh" "$case_dir"
}
