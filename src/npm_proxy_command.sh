mode=${args[mode]}

if [ -z "$mode" ]; then
    echo "npm proxy: $(verdaccio_proxy_mode)"
    exit 0
fi

write_verdaccio_config "$mode"
restart_verdaccio
if [ "$mode" = on ]; then
    log_success "npm proxy on: competitors can install any npm package (fetched from npmjs and cached)"
else
    log_success "npm proxy off: only the packages cached in data/verdaccio can be installed"
fi
