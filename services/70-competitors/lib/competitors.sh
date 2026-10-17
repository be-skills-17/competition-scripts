# shellcheck shell=bash
# Competitors service helpers (loaded with service_hooks.sh)

# Initialize competitors compose file
initialize_competitors_config() {
    log_info "Initializing competitors configuration..."

    mkdir -p "$(dirname "$(service_compose_file competitors)")"
    cat <<EOF > "$(service_compose_file competitors)"
services:
EOF
}

# Add competitor module to Docker Compose configuration
# WUD deploys every new x.y.z tag. No "wud.watch.digest": each CI build of the templates pushes a new tag
# (1.0.<unix time>), and watching digests made WUD ask Gitea for the manifest of the running image every check
# (404 for the initial image, whose first digest is nginx's on Docker Hub).
add_competitor_module_to_compose() {
    local user=$1
    local module=$2
    local subdomain=$3

    cat <<EOF >> "$(service_compose_file competitors)"
  ${user}_${module}:
    image: git.${DOMAIN}/${user}/${module}:1.0.0
    container_name: ${user}_${module}
    restart: always
    networks:
      - gitea
    labels:
      - "wud.watch=true"
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
    cat <<EOF >> "$(service_compose_file competitors)"

networks:
  gitea:
    external: true
EOF
}

# --- Competitor accounts in Gitea (users, team membership, CI secrets) ---

# Create user-level action secret
create_user_secret() {
    local user=$1
    local pass=$2
    local secret_name=$3
    local secret_value=$4
    
    curl -s -k -X PUT \
        -u "$user:$pass" \
        -H "Content-Type: application/json" \
        -d "{\"data\": \"$secret_value\"}" \
        "$GITEA_URL/api/v1/user/actions/secrets/$secret_name" > /dev/null
}

# Create all standard secrets for a user
create_user_secrets() {
    local user=$1
    local pass=$2
    
    log_info "Creating user-level secrets for $user..."
    
    create_user_secret "$user" "$pass" "USER" "$user"
    create_user_secret "$user" "$pass" "PASS" "$pass"
    create_user_secret "$user" "$pass" "DOMAIN" "$DOMAIN"
    create_user_secret "$user" "$pass" "NPM_REGISTRY_URL" "http://verdaccio:4873"
    create_user_secret "$user" "$pass" "SERVER_IP" "127.0.0.1"
}

# Create competitor user in Gitea
create_competitor_user() {
    local username=$1
    local password=$2
    
    log_info "Creating Gitea user: $username"
    docker exec gitea su -c "/app/gitea/gitea admin user create --username '$username' --password '$password' --email '$username@example.com' --must-change-password=false" git
}

# Add user to team
add_competitor_to_team() {
    local org=$1
    local team=$2
    local user=$3
    
    local team_id response

    team_id=$(curl -k -s -H "Authorization: token $GITEA_TOKEN" "$GITEA_URL/api/v1/orgs/$org/teams/search?q=$team" \
        | awk -F'"id":' '{print $2}' | awk -F',' '{print $1}' | head -n 1)
    if [ -z "$team_id" ] || [ "$team_id" == "null" ]; then
        log_error "Failed to retrieve team ID for team '$team' in organization '$org'."
        return 1
    fi

    response=$(curl -k -s -o /dev/null -w "%{http_code}" -X PUT \
        -H "Content-Type: application/json" \
        -H "Authorization: token $GITEA_TOKEN" \
        "$GITEA_URL/api/v1/teams/$team_id/members/$user")
    if [ "$response" -ne 204 ]; then
        log_error "Failed to add user '$user' to team '$team' in organization '$org'. HTTP status code: $response"
        return 1
    fi
    log_info "User '$user' added to team '$team' in organization '$org'."
}
