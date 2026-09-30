#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

if [[ "${1:-}" == "--recreate" ]]; then
    export RECREATE_ENVS=1
elif [[ $# -ne 0 ]]; then
    echo "Usage: $0 [--recreate]" >&2
    exit 2
fi

tests=(
    test-conda.sh
    test-apptainer.sh
    test-pak.sh
)

declare -a names=()
declare -a statuses=()
failures=0

for test_script in "${tests[@]}"; do
    name="${test_script#test-}"
    name="${name%.sh}"
    names+=("$name")

    echo
    echo "================================================================"
    echo "Running installation smoke test: $name"
    echo "================================================================"

    set +e
    "$SCRIPT_DIR/$test_script"
    status=$?
    set -e

    if [[ $status -eq 0 ]]; then
        statuses+=("PASS")
    else
        statuses+=("FAIL ($status)")
        failures=$((failures + 1))
    fi
done

echo
echo "================ Installation smoke summary ================"
for i in "${!names[@]}"; do
    printf '%-12s %s\n' "${names[$i]}" "${statuses[$i]}"
done
echo "Logs and outputs: $SMOKE_ROOT"

if [[ $failures -ne 0 ]]; then
    exit 1
fi
