#!/bin/bash

# Source all utility modules
source "$SCRIPTS_DIR/config.sh"
source "$SCRIPTS_DIR/docker-services.sh"
source "$SCRIPTS_DIR/gitea-setup.sh"
source "$SCRIPTS_DIR/frameworks.sh"
source "$SCRIPTS_DIR/competitors.sh"
source "$SCRIPTS_DIR/environment.sh"

# Initialize configuration
initialize_configuration

# Start core infrastructure
start_core_services

# Wait for Gitea to be ready
wait_for_gitea

# Create admin user and setup runner
create_admin_user "$USERNAME" "$PASSWORD"
generate_registration_token
start_runner_services

# Setup Gitea access and organizations
get_personal_access_token
setup_organizations_and_teams

# Import frameworks
import_all_frameworks
setup_docker_registry_credentials

# Setup competitors
initialize_competitors_config
process_all_competitors "$CONFIG_FILE"
finalize_docker_compose_config

# Start services
start_database_services
start_supporting_services
configure_verdaccio_permissions
start_competitor_services

# Export environment variables
export_environment_variables ".env"

echo "..all done!"

