#!/usr/bin/env bats
# run_with_spinner (src/lib/logging.sh). Without a terminal it prints the output directly.

load test_helper

setup() {
    setup_project
}

@test "the command receives its arguments separately" {
    run run_with_spinner "msg" printf '[%s]' "a b" c
    [[ "$output" == *"[a b][c]"* ]]
}

@test "the exit code of the command is returned" {
    run run_with_spinner "msg" bash -c 'exit 3'
    [ "$status" -eq 3 ]
}

@test "shell functions can be run" {
    my_function() { echo "called with $1"; }
    run run_with_spinner "msg" my_function x
    [[ "$output" == *"called with x"* ]]
}
