# shellcheck shell=bash
# Gitea service helpers: admin, tokens, organizations and teams (loaded with service_hooks.sh)

# Create admin user in Gitea
create_admin_user() {
    local username=$1
    local password=$2
    
    log_info "Creating Gitea admin user: $username"
    docker exec gitea su -c "/app/gitea/gitea admin user create --username $username --password $password --email $username@example.com --admin" git
}

# Generate registration token for Gitea runner
generate_registration_token() {
    log_info "Generating registration token for Gitea runner..."
    local token=$(docker exec gitea su -c '/app/gitea/gitea actions generate-runner-token' git)
    export REGISTRATION_TOKEN=$token
    log_success "Registration Token: $REGISTRATION_TOKEN"
}

# Create organization in Gitea
create_organization() {
    local org_name=$1
    
    log_info "Creating organization: $org_name"
    curl -s -k -X POST "$GITEA_URL/api/v1/orgs" \
        -H "Content-Type: application/json" \
        -H "Authorization: token $GITEA_TOKEN" \
        -d "{
            \"username\": \"$org_name\",
            \"full_name\": \"$org_name\"
        }" > /dev/null
}

# create_pat [name] [scopes as a JSON array]: create a personal access token for the admin and print it.
# Gitea refuses two tokens with the same name. Default scopes: the ones the scripts need (orgs, repositories...).
create_pat() {
    local token_name=${1:-CreateOrganizationScript}
    local scopes=${2:-'["read:admin","write:organization,write:repository,write:user"]'}
    local response new_token

    response=$(curl -s -k -X POST -H "Content-Type: application/json" \
        -u "$USERNAME:$PASSWORD" \
        -d '{
              "name": "'"$token_name"'",
              "scopes": '"$scopes"'
            }' \
        "$GITEA_URL/api/v1/users/$USERNAME/tokens")

    new_token=$(echo "$response" | grep -o '"sha1":"[^"]*"' | sed 's/"sha1":"//;s/"//g')
    if [ -z "$new_token" ] || [ "$new_token" == "null" ]; then
        echo "Failed to create token. Response: $response"
        return 1
    fi
    echo "$new_token"
}

# Returns 0 if $GITEA_TOKEN is accepted by Gitea
gitea_token_is_valid() {
    [ -n "$GITEA_TOKEN" ] || return 1
    [ "$(curl -s -k -o /dev/null -w '%{http_code}' -H "Authorization: token $GITEA_TOKEN" "$GITEA_URL/api/v1/user")" = "200" ]
}

# Use the token stored in .env by init. Installations made before it was stored get a new one,
# under a unique name (Gitea refuses duplicate names), saved to .env so this only happens once.
load_personal_access_token() {
    local env_file=$1
    gitea_token_is_valid && return 0

    log_warning "No valid GITEA_TOKEN in $env_file, creating a new one"
    export GITEA_TOKEN=$(create_pat "competition-scripts-$(date +%Y%m%d%H%M%S)")
    if ! gitea_token_is_valid; then
        log_error "Could not get a Gitea access token: $GITEA_TOKEN"
        return 1
    fi
    sed -i '/^GITEA_TOKEN=/d' "$env_file"
    echo "GITEA_TOKEN=\"$GITEA_TOKEN\"" >> "$env_file"
    log_success "Token saved to $env_file"
}

# Create a team in an organization
create_team() {
    local org=$1
    local team=$2
    local can_create_org_repo=$3
    local response team_id

    response=$(curl -k -s -X POST -H "Content-Type: application/json" \
        -H "Authorization: token $GITEA_TOKEN" \
        -d '{
              "name": "'"$team"'",
              "can_create_org_repo": '"$can_create_org_repo"',
              "units_map": {
                "repo.actions": "read",
                "repo.packages": "none",
                "repo.code": "write",
                "repo.issues": "write",
                "repo.ext_issues": "none",
                "repo.wiki": "admin",
                "repo.pulls": "owner",
                "repo.releases": "none",
                "repo.projects": "none",
                "repo.ext_wiki": "none"
              }
            }' \
        "$GITEA_URL/api/v1/orgs/$org/teams")

    team_id=$(echo "$response" | awk -F'"id":' '{print $2}' | awk -F',' '{print $1}')
    if [ -z "$team_id" ] || [ "$team_id" == "null" ]; then
        log_error "Failed to create team. Response: $response"
        return 1
    fi
    log_info "Created team '$team' (ID: $team_id)"
}

# Setup basic organizations and teams
setup_organizations_and_teams() {
    log_section "Setting up Organizations and Teams"
    
    create_organization "images"
    create_organization "frameworks"
    
    create_team "frameworks" "competitors" false
}

# Poll Gitea until it answers, returns 1 after the last retry
poll_gitea() {
    local retries=10
    local wait=5
    local count=0

    until curl -s http://localhost:3000/api/v1/version > /dev/null; do
        if [ $count -ge $retries ]; then
            return 1
        fi
        log_debug "Gitea health check attempt $((count + 1))/$retries"
        sleep $wait
        count=$((count + 1))
    done
}

# Wait for Gitea to be ready
wait_for_gitea() {
    if ! run_with_spinner "Waiting for Gitea to be ready..." poll_gitea; then
        log_error "Gitea did not become ready in time."
        exit 1
    fi
    log_success "Gitea is ready"
}

