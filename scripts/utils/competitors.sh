#!/bin/bash

# Initialize competitors configuration files
initialize_competitors_config() {
    echo "Initializing competitors configuration..."
    
    cat <<EOF > $DYNAMIC_DOCKER_DIR/competitors.yaml
services:
EOF

    cat <<EOF > $CONFIG_DIR/mysql/competitors.sql
EOF
}

# Add competitor module to Docker Compose configuration
add_competitor_module_to_compose() {
    local user=$1
    local module=$2
    local subdomain=$3
    
    cat <<EOF >> $DYNAMIC_DOCKER_DIR/competitors.yaml
  ${user}_${module}:
    image: git.${DOMAIN}/${user}/${module}:1.0.0
    container_name: ${user}_${module}
    restart: always
    networks:
      - gitea
    labels:
      - "wud.watch=true"
      - "wud.watch.digest=true"
      - "wud.registry=gitea.private"
      - 'wud.tag.include=^\d+\.\d+\.\d+\$\$'
      - "traefik.enable=true"
      - "traefik.http.routers.${user}_${module}.rule=Host(\`${subdomain}-${module}.$DOMAIN\`)"
      - "traefik.http.routers.${user}_${module}.entrypoints=${ENTRYPOINT}"
      - "traefik.http.routers.${user}_${module}.tls=${ENABLE_HTTPS}"
      - "traefik.http.services.${user}_${module}.loadbalancer.server.port=80"
      - "com.centurylinklabs.watchtower.enable=true"
EOF
}

# Add competitor module to MySQL configuration
add_competitor_module_to_sql() {
    local user=$1
    local module=$2
    local pass=$3
    
    cat <<EOF >> $CONFIG_DIR/mysql/competitors.sql
  CREATE DATABASE IF NOT EXISTS \`${user}_${module}\`;
  CREATE USER IF NOT EXISTS '$user'@'%' IDENTIFIED BY '$pass';
  GRANT ALL PRIVILEGES ON \`${user}_${module}\`.* TO '$user'@'%';
EOF
}

# Push initial container image for competitor module
push_initial_module_image() {
    local user=$1
    local module=$2
    
    echo "Pushing initial container for $user/$module"
    docker tag nginx:latest git.$DOMAIN/$user/$module:1.0.0
    docker tag nginx:latest git.$DOMAIN/$user/$module:latest
    
    docker push git.$DOMAIN/$user/$module:1.0.0 > $REDIRECT 2>&1
    docker push git.$DOMAIN/$user/$module:latest > $REDIRECT 2>&1
}

# Process a single competitor module
process_competitor_module() {
    local user=$1
    local module=$2
    local subdomain=$3
    local pass=$4
    
    echo "Processing module: $module for $user"
    
    add_competitor_module_to_compose "$user" "$module" "$subdomain"
    add_competitor_module_to_sql "$user" "$module" "$pass"
    push_initial_module_image "$user" "$module"
}

# Process a single competitor
process_competitor() {
    local config_row=$1
    local config_file=$2
    
    _jq() {
        echo ${config_row} | base64 --decode | jq -r ${1}
    }

    local username=$(_jq '.username')
    local password=$(_jq '.password')
    local subdomain=$(_jq '.subdomain')
    
    echo "Processing competitor: $(_jq '.name')"
    echo "Creating Gitea user: $username with subdomain: $subdomain"
    
    create_competitor_user "$username" "$password"
    add_competitor_to_team "frameworks" "competitors" "$username"
    create_user_secrets "$username" "$password"
    
    for module in $MODULES; do
        process_competitor_module "$username" "$module" "$subdomain" "$password"
    done
}

# Process all competitors from configuration file
process_all_competitors() {
    local config_file=$1
    
    echo "Processing all competitors..."
    
    for row in $(jq -r '.competitors[] | @base64' "$config_file"); do
        process_competitor "$row" "$config_file"
    done
}

# Finalize Docker Compose configuration
finalize_docker_compose_config() {
    cat <<EOF >> $DYNAMIC_DOCKER_DIR/competitors.yaml

networks:
  gitea:
    external: true
EOF
}
