#!/bin/bash

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
    else
        TASK_STATUS+=("FAILED")
        echo " FAILED"
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
    else
        TASK_STATUS+=("FAILED")
        echo " FAILED"
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
            ((success++))
        else
            echo -e "  ${RED}✗${NC} ${TASK_NAMES[$i]}"
            ((failed++))
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
    fi
}

# =============================================================================
# Version and Credentials
# =============================================================================

read_version() {
    VERSION=$(cat "$SCRIPT_DIR/VERSION" | tr -d '[:space:]')
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
    if [[ -z "$RELEASE_LOG_APPEND" ]]; then
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
