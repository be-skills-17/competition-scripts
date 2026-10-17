eval "targets=(${args[service]})"

build_service_map

if [ ${#targets[@]} -eq 0 ]; then
    print_available
    exit 0
fi

for target in "${targets[@]}"; do
    if [ -z "${SERVICE_FILE[$target]}" ] && [ -z "${GROUP_FILE[$target]}" ]; then
        log_error "Unknown service or group: $target"
        echo ""
        print_available
        exit 1
    fi
done

log_section "Recreating Services"
had_failure=0
for target in "${targets[@]}"; do
    if [ -n "${SERVICE_FILE[$target]}" ]; then
        recreate_service "${SERVICE_FILE[$target]}" "$target" || had_failure=1
    else
        file=${GROUP_FILE[$target]}
        for svc in $(docker compose -f "$file" config --services); do
            recreate_service "$file" "$svc" || had_failure=1
        done
    fi
done

if [ "$had_failure" -ne 0 ]; then
    log_error "Some services failed to be recreated"
    exit 1
fi
log_success "Done"
