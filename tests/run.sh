#!/usr/bin/env bash
# Run every check: competition.sh up to date with src/, shellcheck, bats tests.
# Only Docker is needed. Usage: tests/run.sh [bats arguments, e.g. tests/config.bats]
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASHLY_IMAGE="dannyben/bashly:2.0.0"
SHELLCHECK_IMAGE="koalaman/shellcheck:v0.10.0"
TESTS_IMAGE="competition-scripts-tests"

failed=0
step() { printf '\n\033[1;36m▶ %s\033[0m\n' "$1"; }
ok() { printf '\033[0;32m✓ %s\033[0m\n' "$1"; }
ko() { printf '\033[0;31m✗ %s\033[0m\n' "$1"; failed=1; }

step "competition.sh is generated from src/"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -r "$REPO_DIR/src" "$REPO_DIR/bashly-settings.yml" "$tmp/"
if docker run --rm --user "$(id -u):$(id -g)" -v "$tmp:/app" "$BASHLY_IMAGE" generate > /dev/null \
    && cmp -s "$tmp/competition.sh" "$REPO_DIR/competition.sh"; then
    ok "up to date"
else
    ko "competition.sh differs from src/: regenerate it (see README, Development)"
fi

step "shellcheck"
if docker run --rm -v "$REPO_DIR:/mnt" "$SHELLCHECK_IMAGE" -S warning -e SC2155,SC2034,SC2011,SC2154 \
    competition.sh services/*/service.sh tests/run.sh; then
    ok "no warning"
else
    ko "shellcheck found problems"
fi

step "bats"
docker build -q -t "$TESTS_IMAGE" "$REPO_DIR/tests" > /dev/null
if docker run --rm -v "$REPO_DIR:/code:ro" -w /code "$TESTS_IMAGE" "${@:-tests}"; then
    ok "all tests passed"
else
    ko "some tests failed"
fi

echo
if [ "$failed" -ne 0 ]; then
    ko "some checks failed"
    exit 1
fi
ok "all checks passed"
