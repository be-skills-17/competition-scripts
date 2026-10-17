# Initialize competitors compose file
initialize_competitors_config() {
    log_info "Initializing competitors configuration..."

    cat <<EOF > $DYNAMIC_DOCKER_DIR/competitors.yaml
services:
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
EOF
}

# Push initial container image for competitor module
push_initial_module_image() {
    local user=$1
    local module=$2

    log_debug "Pushing initial container for $user/$module"
    docker tag nginx:latest git.$DOMAIN/$user/$module:1.0.0
    docker tag nginx:latest git.$DOMAIN/$user/$module:latest

    run_with_spinner "Pushing initial image for $user/$module..." \
        docker push --all-tags git.$DOMAIN/$user/$module
}

# Process a single competitor module
process_competitor_module() {
    local user=$1
    local module=$2
    local subdomain=$3

    log_debug "Processing module: $module for $user"

    add_competitor_module_to_compose "$user" "$module" "$subdomain"
    push_initial_module_image "$user" "$module"
}

# Process a single competitor
process_competitor() {
    local name=$1
    local username=$2
    local password=$3
    local subdomain=$4

    log_subsection "Competitor: $name (subdomain: $subdomain)"

    create_competitor_user "$username" "$password"
    add_competitor_to_team "frameworks" "competitors" "$username"
    create_user_secrets "$username" "$password"

    for module in $MODULES; do
        process_competitor_module "$username" "$module" "$subdomain"
    done
}

# Process all competitors from configuration file ("name" is optional, the username is shown instead)
process_all_competitors() {
    local config_file=$1
    local name username password subdomain

    log_section "Processing All Competitors"

    while IFS=$'\t' read -r name username password subdomain; do
        process_competitor "$name" "$username" "$password" "$subdomain"
    done < <(jq -r '.competitors[] | [.name // .username, .username, .password, .subdomain] | @tsv' "$config_file")
}

# Finalize Docker Compose configuration
finalize_docker_compose_config() {
    cat <<EOF >> $DYNAMIC_DOCKER_DIR/competitors.yaml

networks:
  gitea:
    external: true
EOF
}
