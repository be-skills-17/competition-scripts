#!/bin/bash

# Create admin user in Gitea
create_admin_user() {
    local username=$1
    local password=$2
    
    echo "Creating Gitea admin user: $username"
    docker exec gitea su -c "/app/gitea/gitea admin user create --username $username --password $password --email $username@example.com --admin" git
}

# Generate registration token for Gitea runner
generate_registration_token() {
    local token=$(docker exec gitea su -c '/app/gitea/gitea actions generate-runner-token' git)
    export REGISTRATION_TOKEN=$token
    echo "Registration Token: $REGISTRATION_TOKEN"
}

# Create organization in Gitea
create_organization() {
    local org_name=$1
    
    echo "Creating organization: $org_name"
    curl -s -k -X POST "$GITEA_URL/api/v1/orgs" \
        -H "Content-Type: application/json" \
        -H "Authorization: token $GITEA_TOKEN" \
        -d "{
            \"username\": \"$org_name\",
            \"full_name\": \"$org_name\"
        }" > /dev/null
}

# Get or create PAT token
get_personal_access_token() {
    export GITEA_TOKEN=$($SCRIPTS_DIR/create_pat.sh "$GITEA_URL" "$USERNAME" "$PASSWORD")
}

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
    
    echo "Creating user-level secrets for $user..."
    
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
    
    echo "Creating Gitea user: $username"
    docker exec gitea su -c "/app/gitea/gitea admin user create --username '$username' --password '$password' --email '$username@example.com' --must-change-password=false" git
}

# Add user to team
add_competitor_to_team() {
    local org=$1
    local team=$2
    local user=$3
    
    $SCRIPTS_DIR/add_user_to_team.sh "$org" "$team" "$user"
}

# Setup basic organizations and teams
setup_organizations_and_teams() {
    echo "Setting up organizations and teams..."
    
    create_organization "images"
    create_organization "frameworks"
    
    $SCRIPTS_DIR/create_team.sh "frameworks" "competitors" false
}
