#!/bin/bash
set -euo pipefail

# =============================================================================
# MPAQT Release Common Functions
# Shared helper functions sourced by release_*.sh scripts
# =============================================================================

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREDS_FILE="$SCRIPT_DIR/release_cred.yml"
LOG_FILE="$SCRIPT_DIR/release_log.txt"

# Task tracking
declare -a TASK_NAMES
declare -a TASK_STATUS

# Colors for summary
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# =============================================================================
# Helper Functions
# =============================================================================

log() {
    echo "$@" >> "$LOG_FILE"
}

log_header() {
    echo "" >> "$LOG_FILE"
    echo "==============================================================================" >> "$LOG_FILE"
    echo "$@" >> "$LOG_FILE"
    echo "==============================================================================" >> "$LOG_FILE"
}

run_task() {
    local name="$1"
    shift
    TASK_NAMES+=("$name")

    echo -n "  Running: $name..."
    log_header "$name"

    if "$@" >> "$LOG_FILE" 2>&1; then
        TASK_STATUS+=("OK")
        echo " done"
        return 0
    else
        TASK_STATUS+=("FAILED")
        echo " FAILED"
        return 1
    fi
}

run_task_inline() {
    # For inline commands that need shell evaluation
    local name="$1"
    local cmd="$2"
    TASK_NAMES+=("$name")

    echo -n "  Running: $name..."
    log_header "$name"

    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        TASK_STATUS+=("OK")
        echo " done"
        return 0
    else
        TASK_STATUS+=("FAILED")
        echo " FAILED"
        return 1
    fi
}

print_summary() {
    echo ""
    echo "==========================================="
    echo "           RELEASE SUMMARY"
    echo "==========================================="

    local success=0
    local failed=0

    for i in "${!TASK_NAMES[@]}"; do
        if [[ "${TASK_STATUS[$i]}" == "OK" ]]; then
            echo -e "  ${GREEN}✓${NC} ${TASK_NAMES[$i]}"
            success=$((success + 1))
        else
            echo -e "  ${RED}✗${NC} ${TASK_NAMES[$i]}"
            failed=$((failed + 1))
        fi
    done

    echo ""
    echo "==========================================="
    echo "  Total: $((success + failed)) | Success: $success | Failed: $failed"
    echo "==========================================="
    echo ""
    echo "Full log: $LOG_FILE"

    if [[ $failed -gt 0 ]]; then
        echo ""
        echo "Check log for details: tail -100 $LOG_FILE"
        return 1
    fi

    return 0
}

# =============================================================================
# Version and Credentials
# =============================================================================

read_version() {
    VERSION=$(tr -d '[:space:]' < "$SCRIPT_DIR/VERSION")
    export VERSION
}

check_credentials() {
    if [[ ! -f "$CREDS_FILE" ]]; then
        echo "ERROR: $CREDS_FILE not found"
        echo ""
        echo "To set up credentials:"
        echo "  1. cp release_cred.yml.template release_cred.yml"
        echo "  2. Edit release_cred.yml with your tokens"
        echo ""
        exit 1
    fi
}

load_credentials() {
    check_credentials

    # Parse credentials from YAML (simple grep-based parsing)
    export DOCKER_USER=$(grep -A3 "^docker:" "$CREDS_FILE" | grep "username:" | sed 's/.*username: *//' | tr -d '"' | tr -d "'")
    export DOCKER_PASSWORD=$(grep -A3 "^docker:" "$CREDS_FILE" | grep "password:" | sed 's/.*password: *//' | tr -d '"' | tr -d "'")
    export SYLABS_USER=$(grep -A3 "^sylabs:" "$CREDS_FILE" | grep "username:" | sed 's/.*username: *//' | tr -d '"' | tr -d "'")
    export SYLABS_TOKEN=$(grep -A3 "^sylabs:" "$CREDS_FILE" | grep "token:" | sed 's/.*token: *//' | tr -d '"' | tr -d "'")
    export CONDA_USER=$(grep -A3 "^conda:" "$CREDS_FILE" | grep "username:" | sed 's/.*username: *//' | tr -d '"' | tr -d "'")
    export CONDA_TOKEN=$(grep -A3 "^conda:" "$CREDS_FILE" | grep "token:" | sed 's/.*token: *//' | tr -d '"' | tr -d "'")
    export GITHUB_USER=$(grep -A3 "^github:" "$CREDS_FILE" | grep "username:" | sed 's/.*username: *//' | tr -d '"' | tr -d "'")
    export GITHUB_TOKEN=$(grep -A3 "^github:" "$CREDS_FILE" | grep "token:" | sed 's/.*token: *//' | tr -d '"' | tr -d "'")
}

init_log() {
    # Clear log file unless RELEASE_LOG_APPEND is set (for release_all.sh)
    if [[ -z "${RELEASE_LOG_APPEND:-}" ]]; then
        > "$LOG_FILE"
    fi
}

print_header() {
    local title="$1"
    echo "==========================================="
    echo "       $title"
    echo "==========================================="
    echo ""
    echo "Log file: $LOG_FILE"
    echo ""
}

require_clean_release_commit() {
    local tag="v${VERSION}"
    local head_commit
    local tag_commit
    local tag_type

    if [[ -n "$(git -C "$SCRIPT_DIR" status --porcelain)" ]]; then
        echo "ERROR: Release builds require a clean working tree"
        return 1
    fi

    head_commit=$(git -C "$SCRIPT_DIR" rev-parse HEAD)
    if ! tag_commit=$(git -C "$SCRIPT_DIR" rev-parse "${tag}^{commit}" 2>/dev/null); then
        echo "ERROR: Missing release tag ${tag}"
        return 1
    fi

    tag_type=$(git -C "$SCRIPT_DIR" cat-file -t "$tag")
    if [[ "$tag_type" != "tag" ]]; then
        echo "ERROR: ${tag} must be an annotated tag"
        return 1
    fi

    if [[ "$tag_commit" != "$head_commit" ]]; then
        echo "ERROR: ${tag} does not point to the current commit"
        return 1
    fi
}

require_published_release_tag() {
    local tag="v${VERSION}"
    local local_commit
    local remote_commit

    require_clean_release_commit || return 1
    local_commit=$(git -C "$SCRIPT_DIR" rev-parse "${tag}^{commit}")
    if ! remote_commit=$(
        git -C "$SCRIPT_DIR" ls-remote origin "refs/tags/${tag}^{}" |
            awk 'NR == 1 { print $1 }'
    ); then
        echo "ERROR: Unable to query origin for ${tag}"
        return 1
    fi

    if [[ -z "$remote_commit" ]]; then
        echo "ERROR: ${tag} is not available as an annotated tag on origin"
        return 1
    fi

    if [[ "$remote_commit" != "$local_commit" ]]; then
        echo "ERROR: origin/${tag} does not match the local release commit"
        return 1
    fi
}
