#!/bin/bash

# Create a backup of the whole environment (data, config, generated compose file, .env).
# Services are stopped during the copy so the MySQL files are consistent, then started again.

source "$SCRIPTS_DIR/logging.sh"
source "$SCRIPTS_DIR/backup.sh"

log_section "Backing up Competition Environment"

was_running=false
if project_is_running; then
    was_running=true
    log_subsection "Stopping services for a consistent copy"
    bash "$ACTIONS_DIR/stop.sh"
fi

log_subsection "Archiving"
create_backup_archive "manual"
status=$?

if [ "$was_running" = true ]; then
    log_subsection "Starting services again"
    bash "$ACTIONS_DIR/start.sh"
fi

exit $status
