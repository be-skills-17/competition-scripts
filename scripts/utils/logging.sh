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
    echo -ne "\r"
}
