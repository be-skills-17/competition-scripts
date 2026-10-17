# shellcheck shell=bash
# Gitea service helpers: frameworks templates import (loaded with service.sh)

# Import a framework from a local path
import_framework() {
    local framework_path=$1
    local framework_name=$2
    
    # Check if .npmrc exists and replace ##DOMAIN## with actual domain
    if [ -f "$framework_path/.npmrc" ]; then
        log_info "Found .npmrc in $framework_name, replacing ##DOMAIN## with $DOMAIN"
        sed -i "s/##DOMAIN##/$DOMAIN/g" "$framework_path/.npmrc"
        log_info ".npmrc updated with domain: $DOMAIN"
    fi
    
    push_framework_repo "$framework_path" "$framework_name"
}

# Create (or update) the template repository <name> in the "frameworks" organization from a local folder.
# Runs in a subshell: it changes directory and may exit early.
push_framework_repo() (
    local repo_path=$1
    local repo_name=$2
    local org_name='frameworks'
    local host="git.${DOMAIN}"
    local remote_url="https://$USERNAME:$PASSWORD@$host/$org_name/$repo_name.git"

    cd "$repo_path" || exit 1

    local repo_status
    repo_status=$(curl -s -k -o /dev/null -w '%{http_code}' -H "Authorization: token $GITEA_TOKEN" "https://$host/api/v1/repos/$org_name/$repo_name")

    if [ "$repo_status" = "200" ]; then
        # The template already exists: commit the new content on top of its history instead of recreating it,
        # so repositories generated from it keep their link and nothing is force-pushed.
        echo "Repository $repo_name already exists, updating it..."
        rm -rf .git
        local tmp_clone
        tmp_clone=$(mktemp -d)
        if ! git -c http.sslVerify=false clone --quiet --no-checkout "$remote_url" "$tmp_clone" > $REDIRECT 2>&1; then
            rm -rf "$tmp_clone"
            echo "Failed to clone $org_name/$repo_name from Gitea"
            exit 1
        fi
        mv "$tmp_clone/.git" .git
        rm -rf "$tmp_clone"
        git config user.name "Init Bot"
        git config user.email "init-bot@$DOMAIN"
        git config http.sslVerify false

        git add -A
        if git diff --cached --quiet; then
            echo "Repository $repo_name is already up to date."
            exit 0
        fi
        git commit -m "Update framework" > $REDIRECT 2>&1
        git push origin HEAD > $REDIRECT 2>&1 || {
            echo "Failed to push $repo_name to Gitea"
            exit 1
        }
        echo "Repository $repo_name updated in the $org_name organization !"
        exit 0
    fi

    echo "Configuring git repository..."
    git init -b main > $REDIRECT 2>&1
    git config user.name "Init Bot"
    git config user.email "init-bot@$DOMAIN"
    git config http.sslVerify false

    echo "Commiting changes..."
    git add -A
    git commit -m "Initial commit" > $REDIRECT 2>&1

    echo "Creating the repository on Gitea"
    local create_repo_response
    create_repo_response=$(curl -s -k -X POST "https://$host/api/v1/orgs/$org_name/repos" \
        -H "Authorization: token $GITEA_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
          "name": "'"$repo_name"'",
          "private": false,
          "template": true
        }')

    if echo "$create_repo_response" | grep -q '"id":'; then
        echo "Repository $repo_name created in the $org_name organization on Gitea."
    else
        echo "Failed to create repository on Gitea: $create_repo_response"
        exit 1
    fi

    echo "Pushing the repository to Gitea..."
    git remote remove gitea 2>/dev/null
    git remote add gitea "$remote_url"
    git push -u gitea main --force > $REDIRECT 2>&1

    echo "Repository $repo_name pushed to the $org_name organization !"
)

# Setup Docker credentials for registry
setup_docker_registry_credentials() {
    log_info "Setting up Docker registry credentials..."
    
    run_with_spinner "Pulling nginx image..." docker pull nginx:latest
    docker login -u $USERNAME -p $PASSWORD git.$DOMAIN > /dev/null 2>&1
    log_success "Docker registry credentials configured"
}

# Clone and process frameworks repository, importing only allowed frameworks (config/main.json "frameworks")
import_all_frameworks() {
    local FRAMEWORKS_REPO ALLOWED_FRAMEWORKS
    FRAMEWORKS_REPO=$(jq -r '.frameworks.frameworks_repo' "$CONFIG_DIR/main.json")
    ALLOWED_FRAMEWORKS=$(jq -r '.frameworks.allowed_frameworks // [] | join(" ")' "$CONFIG_DIR/main.json")

    log_section "Importing Frameworks"


    if [ -z "$ALLOWED_FRAMEWORKS" ]; then
        log_warning "No allowed_frameworks configured, importing all frameworks"
    fi

    # Temporary clone, removed once imported
    local clone
    clone=$(mktemp -d)
    run_with_spinner "Cloning frameworks repository..." git clone "$FRAMEWORKS_REPO" "$clone" || { rm -rf "$clone"; exit 1; }

    cd "$clone" || exit 1
    rm -rf "$clone/.git"

    local imported=() failed=()
    for dir in */; do
        [ -d "$dir" ] || continue
        framework_name=$(basename "$dir")

        # Skip frameworks not in the allow list (exact, case-sensitive match)
        if [ -n "$ALLOWED_FRAMEWORKS" ] && [[ " $ALLOWED_FRAMEWORKS " != *" $framework_name "* ]]; then
            log_info "Skipping $framework_name (not in allowed_frameworks)"
            continue
        fi

        framework_path=$(realpath "$dir")
        log_subsection "Framework: $framework_name"
        if run_with_spinner "Importing $framework_name..." import_framework "$framework_path" "$framework_name"; then
            log_success "$framework_name imported"
            imported+=("$framework_name")
        else
            failed+=("$framework_name")
        fi
    done

    # Warn about allowed frameworks that don't exist in the repository
    for allowed in $ALLOWED_FRAMEWORKS; do
        [[ " ${imported[*]} ${failed[*]} " == *" $allowed "* ]] || log_warning "Allowed framework '$allowed' not found in repository"
    done

    log_success "Imported ${#imported[@]} framework(s): ${imported[*]}"
    [ ${#failed[@]} -eq 0 ] || log_error "Failed: ${failed[*]}"
    cd - > /dev/null || exit 1
    rm -rf "$clone"
    [ ${#failed[@]} -eq 0 ]
}
