# Also run by init (post_init of the verdaccio service) and import-frameworks
log_section "Prefetching npm packages"
if [[ ${args[--keep-online]} ]]; then
    prefetch_npm_packages --keep-online
else
    prefetch_npm_packages
fi
