# Configuration

The environment is configured using a JSON file at `config/main.json`. Below is the structure:

```json
{
  "domain": "local.skill17.com",
  "enable_https": true,
  "username": "admin",
  "password": "your_secure_password",
  "modules": ["module-a", "module-b"],
  "frameworks": {
    "frameworks_repo": "https://github.com/your-org/frameworks.git",
    "allowed_frameworks": ["laravel", "react", "vuejs"]
  },
  "competitors": [
    {
      "name": "Competitor 1",
      "username": "comp01",
      "password": "comp01_password",
      "subdomain": "comp01"
    },
    {
      "name": "Competitor 2",
      "username": "comp02",
      "password": "comp02_password",
      "subdomain": "comp02"
    }
  ]
}
```

**Key settings:**

1. **domain**: The main domain for the competition.
   - Example: `local.skill17.com`

2. **enable_https**: Enable (`true`) or disable (`false`) HTTPS/SSL.
   - Set to `true` for production, `false` for local development

3. **username / password**: Admin credentials for Gitea.
   - These are used to create the admin user in Gitea

4. **modules**: List of module/project names for competitors.
   - Example: `["frontend", "backend", "devops"]`

5. **frameworks.frameworks_repo**: Git repository URL containing framework templates.
   - These templates are cloned and imported for competitors to use
   - **frameworks.allowed_frameworks** (optional): only these frameworks are imported; all of them if omitted

6. **competitors**: Array of competitor configurations.
   - Each competitor needs: `username`, `password`, and `subdomain`; `name` is optional (display only)
   - Databases are automatically created per competitor per module

**Validation:** `init` and `import-frameworks` check `config/main.json` first and list every problem before
doing anything. To check it on its own: `sudo ./competition.sh check-config`. Rules:
- `username`, `subdomain` and module names: lowercase letters, digits and dashes only (they are used in
  domain names, container names, image paths and database names), each username and subdomain used once;
- passwords: no quotes, backslashes or control characters such as tabs (they are inserted as-is in SQL
  and JSON);
- `enable_https`: `true` or `false` (not a string).
