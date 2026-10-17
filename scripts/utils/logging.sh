#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Log functions
log_info() {
    echo -e "${BLUE}ℹ${NC}  $@"
}

log_success() {
    echo -e "${GREEN}✓${NC}  $@"
}

log_error() {
    echo -e "${RED}✗${NC}  $@" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠${NC}  $@"
}

log_section() {
    echo ""
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}▶  $@${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_subsection() {
    echo -e "${BOLD}${MAGENTA}→  $@${NC}"
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}🔍  $@${NC}"
    fi
}

# Spinner for long-running operations
show_spinner() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spinner=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )

    while kill -0 $pid 2>/dev/null; do
        for i in "${spinner[@]}"; do
            echo -ne "\r${CYAN}$i${NC}  ${message}"
            sleep $delay
        done
    done
    echo -ne "\r\033[K"
}

# Run a command (or function) behind a spinner. Its output is hidden, and printed only if it fails.
# In verbose mode, or when the output is not a terminal, the output is shown directly instead.
run_with_spinner() {
    local message=$1
    shift

    if [ "$VERBOSE" = true ] || [ ! -t 1 ]; then
        log_info "$message"
        "$@"
        return
    fi

    local output pid status
    output=$(mktemp)
    "$@" > "$output" 2>&1 &
    pid=$!
    # Background jobs ignore Ctrl+C in scripts: stop it ourselves
    trap 'kill $pid 2>/dev/null; echo -ne "\r\033[K"; rm -f "$output"; exit 130' INT TERM
    show_spinner $pid "$message"
    wait $pid
    status=$?
    trap - INT TERM

    if [ $status -ne 0 ]; then
        log_error "$message (failed)"
        cat "$output" >&2
    fi
    rm -f "$output"
    return $status
}
