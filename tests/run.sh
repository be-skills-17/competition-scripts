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

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# The APIs template, used by the tests. A clone may leave it out of the working tree (sparse checkout, see
# docs/development.md): it is then taken from HEAD, in $tmp, and mounted next to the code
api_template="$REPO_DIR/config/apis/template"
template_mount=()
if [ ! -d "$api_template" ]; then
    git -C "$REPO_DIR" archive HEAD config/apis/template | tar -x -C "$tmp" || exit 1
    api_template="$tmp/config/apis/template"
    template_mount=(-v "$api_template:/api-template:ro" -e API_TEMPLATE_DIR=/api-template)
fi

step "competition.sh is generated from src/"
cp -r "$REPO_DIR/src" "$REPO_DIR/bashly-settings.yml" "$tmp/"
if docker run --rm --user "$(id -u):$(id -g)" -v "$tmp:/app" "$BASHLY_IMAGE" generate > /dev/null \
    && cmp -s "$tmp/competition.sh" "$REPO_DIR/competition.sh"; then
    ok "up to date"
else
    ko "competition.sh differs from src/: regenerate it (see docs/development.md)"
fi

step "shellcheck"
if docker run --rm -v "$REPO_DIR:/mnt" "$SHELLCHECK_IMAGE" -S warning -e SC2155,SC2034,SC2011,SC2154 \
    competition.sh services/*/*.sh services/*/lib/*.sh tests/run.sh; then
    ok "no warning"
else
    ko "shellcheck found problems"
fi

step "PHP syntax (portal, APIs template)"
if docker run --rm -v "$REPO_DIR:/code:ro" -v "$api_template:/api-template:ro" -w /code php:8.3.26-apache sh -c \
    'find services /api-template -name "*.php" -print0 | xargs -0 -n1 php -l > /dev/null'; then
    ok "no syntax error"
else
    ko "PHP syntax errors"
fi

step "bats"
docker build -q -t "$TESTS_IMAGE" "$REPO_DIR/tests" > /dev/null
if docker run --rm -v "$REPO_DIR:/code:ro" "${template_mount[@]}" -w /code "$TESTS_IMAGE" "${@:-tests}"; then
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
