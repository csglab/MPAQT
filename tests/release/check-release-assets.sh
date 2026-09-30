#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
VERSION="$(tr -d '[:space:]' < VERSION)"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

assert_no_active_match() {
    local pattern="$1"
    shift

    if rg --pcre2 -n "^(?!\\s*#).*(?:${pattern})" "$@"; then
        fail "found an active CLI release line matching: ${pattern}"
    fi
}

assert_conda_run_dependency() {
    local recipe="$1"
    local dependency="$2"

    if ! awk '
        /^  run:$/ { in_run = 1; next }
        in_run && /^  [[:alpha:]_]+:$/ { exit }
        in_run { print }
    ' "$recipe" | rg -q "^    - ${dependency}([[:space:]]|$)"; then
        fail "$recipe is missing required runtime dependency: ${dependency}"
    fi
}

# The unfinished CLI remains archived in the R package, but release artifacts
# must not install it on PATH or advertise it as a supported interface.
[[ -f inst/bin/mpaqt ]] || fail "inst/bin/mpaqt must remain preserved"

assert_no_active_match 'r-optparse' \
    inst/conda/environment.yml \
    inst/conda/environment_full.yml \
    inst/conda/environment_dev.yml \
    inst/conda-recipe/meta.yaml \
    inst/conda-recipe/meta-full.yaml \
    inst/conda-recipe/meta-dev.yaml
assert_no_active_match '(ln -sf|cp ).*bin/mpaqt|chmod .*bin/mpaqt' \
    inst/conda-recipe/build.sh \
    inst/docker/Dockerfile \
    inst/docker/Dockerfile.full \
    inst/docker/Dockerfile.dev \
    inst/apptainer/mpaqt.def \
    inst/apptainer/mpaqt-full.def \
    inst/apptainer/mpaqt-dev.def
assert_no_active_match 'mpaqt --help|mpaqt (index|prepare-sr|prepare-lr|quant|quant-sc|run)' \
    inst/conda-recipe/meta.yaml \
    inst/conda-recipe/meta-full.yaml \
    inst/conda-recipe/meta-dev.yaml \
    inst/docker/build-and-push.sh \
    inst/docker/build-and-push-full.sh \
    inst/docker/build-and-push-dev.sh \
    inst/apptainer/mpaqt.def \
    inst/apptainer/mpaqt-full.def \
    inst/apptainer/mpaqt-dev.def

assert_no_active_match 'conda install .*mamba|/mamba env create' \
    inst/docker/Dockerfile \
    inst/docker/Dockerfile.full \
    inst/docker/Dockerfile.dev \
    inst/apptainer/mpaqt.def \
    inst/apptainer/mpaqt-full.def \
    inst/apptainer/mpaqt-dev.def

# mpaqt_index() calls both packages directly, so every published Conda
# variant must install them as runtime dependencies.
for recipe in \
    inst/conda-recipe/meta.yaml \
    inst/conda-recipe/meta-full.yaml \
    inst/conda-recipe/meta-dev.yaml
do
    assert_conda_run_dependency "$recipe" bioconductor-biostrings
    assert_conda_run_dependency "$recipe" bioconductor-rtracklayer
done

# Local-only and large development content must never enter the source tarball.
for pattern in \
    '^\^debug\$$' \
    '^\^build\$$' \
    '^\^AGENTS\\\.md\$$' \
    '^\^\\\.lintr\\\.R\$$' \
    '^\^\\\.agents\$$' \
    '^\^\\\.codex\$$'
do
    rg -q "$pattern" .Rbuildignore ||
        fail ".Rbuildignore is missing required pattern: ${pattern}"
done

# Every Conda variant must build the exact public release tag.
for recipe in \
    inst/conda-recipe/meta.yaml \
    inst/conda-recipe/meta-full.yaml \
    inst/conda-recipe/meta-dev.yaml
do
    rg -q '^  git_url: https://github\.com/csglab/MPAQT_merged\.git$' "$recipe" ||
        fail "$recipe does not use the csglab repository"
    rg -q "^  git_rev: v${VERSION//./\\.}$" "$recipe" ||
        fail "$recipe is not pinned to v${VERSION}"
done

# Release scripts must stop on failures, and uploads must not overwrite builds.
for script in \
    release_all.sh \
    release_apptainer.sh \
    release_common.sh \
    release_conda.sh \
    release_docker.sh \
    release_rbuild.sh \
    inst/apptainer/build-and-push.sh \
    inst/apptainer/build-and-push-full.sh \
    inst/apptainer/build-and-push-dev.sh \
    inst/conda-recipe/build-and-upload.sh \
    inst/conda-recipe/build-and-upload-full.sh \
    inst/conda-recipe/build-and-upload-dev.sh \
    inst/conda-recipe/build.sh \
    inst/docker/build-and-push.sh \
    inst/docker/build-and-push-full.sh \
    inst/docker/build-and-push-dev.sh
do
    rg -q '^set -e(u|ux)o pipefail$' "$script" ||
        fail "$script does not enable safe shell mode"
done

if rg -n 'anaconda .*upload .*--force' inst/conda-recipe/build-and-upload*.sh; then
    fail "Conda uploads must not overwrite an existing release build"
fi

if rg -n 'sed -i' release_rbuild.sh; then
    fail "release_rbuild.sh must verify, not rewrite, a tagged release"
fi

rg -q 'Verify clean release tree preserved' release_rbuild.sh ||
    fail "release_rbuild.sh must reject generated changes from a clean release tree"

tmp_log="$(mktemp)"
trap 'rm -f "$tmp_log"' EXIT
source ./release_common.sh
LOG_FILE="$tmp_log"
unset RELEASE_LOG_APPEND || true
init_log
if run_task "intentional failure" false >/dev/null 2>&1; then
    fail "run_task incorrectly returned success for a failed command"
fi

echo "Release asset checks passed."
