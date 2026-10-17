name=${args[api]}
competitor=${args[competitor]}

dir=$(api_dir_by_name "$name") || { log_error "No enabled API named \"$name\""; exit 1; }
if [ -z "$(api_field "$dir" '.sqlite // empty')" ]; then
    log_error "API \"$name\" has no SQLite database (no \"sqlite\" in its api.json)"
    exit 1
fi
if [ -n "$competitor" ] && ! jq -e --arg u "$competitor" '.competitors | any(.username == $u)' "$CONFIG_DIR/main.json" > /dev/null; then
    log_error "Unknown competitor: $competitor"
    exit 1
fi

log_section "Resetting API $name"
if [ -n "$competitor" ]; then
    containers=("${competitor}_${name}")
else
    mapfile -t containers < <(jq -r --arg n "$name" '.competitors[] | "\(.username)_\($n)"' "$CONFIG_DIR/main.json")
fi

# Stopped while the database is replaced, so no request writes to the old one
docker stop "${containers[@]}" > /dev/null 2>&1
prepare_api_data "$dir" "$competitor" true
docker start "${containers[@]}" > /dev/null
log_success "Database reset for: ${containers[*]}"
