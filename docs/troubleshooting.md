# Troubleshooting

## Services not starting
- Check Docker is running: `docker ps`
- View logs: `docker compose -f services/20-gitea/compose.yaml logs`
- Use verbose mode: `sudo ./competition.sh -v init`

## Configuration issues
- Verify `config/main.json` is valid JSON: `jq . config/main.json`
- Check that `frameworks_repo` is accessible
- Ensure all required fields are present

## Cleaning up
- To reset everything: `sudo ./competition.sh clean`
- To stop without removing data: `sudo ./competition.sh stop`
- To restart: `sudo ./competition.sh start`
