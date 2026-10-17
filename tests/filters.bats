#!/usr/bin/env bats
# Filters used by the commands (src/lib/filters.sh)

load test_helper

setup() {
    setup_project
}

@test "initialized passes when the lock file exists" {
    touch "$LOCK_FILE"
    run filter_initialized
    [ -z "$output" ]
}

@test "initialized fails without the lock file" {
    run filter_initialized
    [[ "$output" == *"not initialized"* ]]
}

@test "not_initialized fails when the lock file exists" {
    touch "$LOCK_FILE"
    run filter_not_initialized
    [[ "$output" == *"already initialized"* ]]
}

@test "not_initialized passes without the lock file" {
    run filter_not_initialized
    [ -z "$output" ]
}
