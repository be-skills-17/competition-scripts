if [[ ${args[--no-backup]} ]]; then
    clean_environment false
else
    clean_environment true
fi
