log_section "Stopping Services"
compose_each --reverse stop
log_success "Services stopped"
