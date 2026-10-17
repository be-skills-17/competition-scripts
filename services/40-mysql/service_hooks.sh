# shellcheck shell=bash
# MySQL: one database per competitor and module, plus phpMyAdmin

# competitors.sql is run by the MySQL entrypoint on first start only (empty data directory)
service_mysql_pre_init() {
    log_info "Generating competitors databases..."
    : > "$CONFIG_DIR/mysql/competitors.sql"

    local user pass module
    while IFS=$'\t' read -r user pass; do
        for module in $MODULES; do
            add_competitor_module_to_sql "$user" "$module" "$pass"
        done
    done < <(jq -r '.competitors[] | [.username, .password] | @tsv' "$CONFIG_FILE")
}
