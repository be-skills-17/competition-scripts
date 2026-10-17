# Re-importing frameworks

`import-frameworks` clones `frameworks_repo` again and imports the frameworks listed in `allowed_frameworks`
(both read from `config/main.json`), without touching anything else:

- A template that already exists in the `frameworks` organization gets a new "Update framework" commit (nothing is
  done if its content did not change). It is never deleted or force-pushed, so repositories competitors created from
  it are not affected and keep their "generated from" link.
- A framework newly added to `allowed_frameworks` is created as a new template.
- A framework removed from `allowed_frameworks` stays in Gitea; delete it from the web UI if needed.
