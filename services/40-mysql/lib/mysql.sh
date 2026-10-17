# shellcheck shell=bash
# MySQL service helpers: competitors.sql (loaded with service_hooks.sh)

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

