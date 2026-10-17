#!/usr/bin/env bats
# Backup archives and backup lookup (src/lib/backup.sh)

load test_helper

setup() {
    setup_project
    mkdir -p "$DATA_DIR/gitea" "$DYNAMIC_DIR/portal"
    echo '{}' > "$DYNAMIC_DIR/portal/portal.json"
    echo repo > "$DATA_DIR/gitea/file"
    echo 'DOMAIN="competition.test"' > "$BASE_DIR/.env"
    touch "$LOCK_FILE"
}

@test "nothing is archived when there is no data directory" {
    rm -rf "$DATA_DIR"
    create_backup_archive test
    [ -z "$LAST_BACKUP_FILE" ]
    [ ! -d "$BACKUP_DIR" ]
}

@test "the archive contains data, config, the generated files, .env and the lock" {
    create_backup_archive test > /dev/null
    run tar -tzf "$LAST_BACKUP_FILE"
    [[ "$output" == *"data/gitea/file"* ]]
    [[ "$output" == *"config/main.json"* ]]
    [[ "$output" == *"dynamic/portal/portal.json"* ]]
    [[ "$output" == *".env"* ]]
    [[ "$output" == *"competition.lock"* ]]
}

@test "the archive name contains the label" {
    create_backup_archive clean > /dev/null
    [[ "$LAST_BACKUP_FILE" == "$BACKUP_DIR"/backup-*-clean.tar.gz ]]
}

@test "archives and the backups directory are readable by their owner only" {
    create_backup_archive test > /dev/null
    [ "$(stat -c %a "$BACKUP_DIR")" = "700" ]
    [ "$(stat -c %a "$LAST_BACKUP_FILE")" = "600" ]
}

@test "latest resolves to the most recent backup" {
    mkdir -p "$BACKUP_DIR"
    touch -d '2 days ago' "$BACKUP_DIR/backup-old.tar.gz"
    touch "$BACKUP_DIR/backup-new.tar.gz"
    run resolve_backup latest
    [ "$output" = "$BACKUP_DIR/backup-new.tar.gz" ]
}

@test "a file name is looked up in the backups directory" {
    mkdir -p "$BACKUP_DIR"
    touch "$BACKUP_DIR/backup-x.tar.gz"
    run resolve_backup backup-x.tar.gz
    [ "$output" = "$BACKUP_DIR/backup-x.tar.gz" ]
}

@test "a path outside the backups directory is accepted" {
    touch "$BATS_TEST_TMPDIR/elsewhere.tar.gz"
    run resolve_backup "$BATS_TEST_TMPDIR/elsewhere.tar.gz"
    [ "$output" = "$BATS_TEST_TMPDIR/elsewhere.tar.gz" ]
}

@test "an unknown backup resolves to nothing" {
    run resolve_backup nope.tar.gz
    [ -z "$output" ]
}

@test "latest resolves to nothing without backups" {
    run resolve_backup latest
    [ -z "$output" ]
}
