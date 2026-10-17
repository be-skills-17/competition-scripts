# shellcheck shell=bash
# MySQL: one database per competitor and module, plus phpMyAdmin

# Add competitor module to MySQL configuration
add_competitor_module_to_sql() {
    local user=$1
    local module=$2
    local pass=$3

    cat <<SQL >> "$CONFIG_DIR/mysql/competitors.sql"
  CREATE DATABASE IF NOT EXISTS \`${user}_${module}\`;
  CREATE USER IF NOT EXISTS '$user'@'%' IDENTIFIED BY '$pass';
  GRANT ALL PRIVILEGES ON \`${user}_${module}\`.* TO '$user'@'%';
SQL
}

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
