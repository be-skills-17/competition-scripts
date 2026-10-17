# Remove every container, data, generated file and competitor image.
# With do_backup=true (default), a backup is made once the services are down; if it fails nothing is deleted.
clean_environment() {
    local do_backup=${1:-true}

    load_configuration

    log_section "Cleaning Competition Environment"

    log_subsection "Stopping Docker Services"
    compose_each --reverse down -v
    # Containers whose compose file is missing (moved, deleted...) are still labelled with the project
    local leftovers
    leftovers=$(docker ps -aq --filter "label=com.docker.compose.project=$COMPOSE_PROJECT_NAME")
    if [ -n "$leftovers" ]; then
        log_warning "Removing $(wc -w <<< "$leftovers") container(s) without compose file"
        docker rm -f -v $leftovers > /dev/null
    fi
    log_success "Docker services stopped"

    # Services are down at this point, so the copy is consistent
    if [ "$do_backup" = true ]; then
        log_subsection "Backing up before removing anything"
        if ! create_backup_archive "clean"; then
            log_error "Backup failed, nothing was deleted. Use --no-backup to clean anyway."
            exit 1
        fi
    else
        log_warning "Skipping backup (--no-backup)"
    fi

    log_subsection "Removing Data Volumes"
    rm -rf "$DATA_DIR"
    log_success "Data volumes removed"

    local name
    for name in $(service_names_reversed); do
        run_service_hook "$name" clean
    done

    log_subsection "Cleaning up Dynamic Directories"
    rm -rf "$DYNAMIC_DIR"
    rm -f "$LOCK_FILE"
    log_success "Dynamic directories cleaned"

    echo ""
    log_success "Clean complete! Environment reset. 🧹"
}
