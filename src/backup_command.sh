# Services are stopped during the copy so the MySQL files are consistent, then started again
log_section "Backing up Competition Environment"

was_running=false
if project_is_running; then
    was_running=true
    log_subsection "Stopping services for a consistent copy"
    compose_each --reverse stop
fi

log_subsection "Archiving"
create_backup_archive "manual"
status=$?

if [ "$was_running" = true ]; then
    log_subsection "Starting services again"
    compose_each start
fi

exit $status
