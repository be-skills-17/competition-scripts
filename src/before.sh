# Runs after argument parsing and filters, before any command

if [[ ${args[--verbose]} ]]; then
    export VERBOSE=true
    export REDIRECT=/dev/stdout
fi
