# Competition Environment Setup

## Description
This project provides a simple, reliable, and efficient environment for web development competitions. Using Docker along with Gitea, Traefik, WUD, Verdaccio, and MySQL, it allows organizers to set up a consistent competition environment with minimal effort. Competitors can focus on their work without worrying about complex configurations.

The environment includes:
1. **Docker**: Ensures consistent setups across systems.
2. **Traefik**: Routes requests to the right services with SSL support.
3. **Gitea**: A self-hosted Git server for version control and CI/CD.
4. **Verdaccio**: Private NPM registry for package management.
5. **WUD**: Automatic Docker image updates for competitors.
6. **MySQL**: Manages competition data and per-competitor databases.

## Setting up the Environment

### Quick Start

Get your system ready with a single command:

```bash
# Install all dependencies (Docker, jq, git, curl, etc.)
sudo ./competition.sh setup

# Configure your competition in config/main.json
# Then initialize the environment
./competition.sh init
```

### Prerequisites

The `setup` action automatically installs all required dependencies:
- **Docker** & **Docker Compose**
- **jq** - for JSON parsing
- **git** - for repository management
- **curl** - for API calls
- **wget** - for downloads
- **certbot** - for SSL certificates

If you prefer to install dependencies manually, see [Manual Installation](#manual-installation).

### Commands

All commands use the main `./competition.sh` script with actions:

```bash
# Install all dependencies (requires sudo, run once)
sudo ./competition.sh setup

# Initialize the environment (generates configs, starts services)
./competition.sh init

# Start all services
./competition.sh start

# Stop all services
./competition.sh stop

# Clean the entire system (removes volumes, images, configs)
./competition.sh clean
```

**Verbose mode** (shows debug information):
```bash
./competition.sh -v init
./competition.sh --verbose start
```

**Note:** If you have previously run `./competition.sh init`, make sure to clean the environment first by running `./competition.sh clean` before initializing again. This ensures a fresh setup and avoids potential conflicts. Do NOT manually delete `competition.lock`, it's there as a safeguard and should only be cleared with `./competition.sh clean`

### Configuration
The environment is configured using a JSON file at `config/main.json`. Below is the structure:

```json
{
  "domain": "local.skill17.com",
  "enable_https": true,
  "username": "admin",
  "password": "your_secure_password",
  "modules": ["module_a", "module_b"],
  "frameworks_repo": "https://github.com/your-org/frameworks.git",
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

5. **frameworks_repo**: Git repository URL containing framework templates.
   - These templates are cloned and imported for competitors to use

6. **competitors**: Array of competitor configurations.
   - Each competitor needs: `name`, `username`, `password`, and `subdomain`
   - Databases are automatically created per competitor per module

### Manual Installation

If you prefer to install dependencies manually instead of using `./competition.sh setup`:

**For Debian/Ubuntu:**
```bash
# Update package manager
sudo apt update
sudo apt upgrade -y

# Install basic tools
sudo apt install -y curl wget git ca-certificates gnupg lsb-release

# Install jq (JSON parser)
sudo apt install -y jq

# Install Docker (Official Docker installation)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to docker group (to use docker without sudo)
sudo usermod -aG docker $USER
newgrp docker  # Activate the new group

# Install certbot for SSL (optional but recommended)
sudo apt install -y certbot
```

**Verify Installation:**
```bash
docker --version
docker compose version
jq --version
git --version
```

## Using the Environment

- **Git Server (Gitea):**
  Access through the `git` subdomain of your configured domain.
  - Example: `https://git.local.skill17.com`
  - Default admin: `admin` / `your_secure_password`

- **Competitors' Work:**
  Competitors' projects can be accessed using their subdomain and the module name.
  - Format: `https://<subdomain>-<module_name>.<domain>`
  - Example: `https://qwer-module-a.local.skill17.com`

- **Database Entries:**
  MySQL is automatically configured with:
  - Per-competitor databases: `comp01_module_a`, `comp01_module_b`, etc.
  - Automatic user creation with appropriate permissions
  - Users can access only their own databases

## Competitor Workflow

### Creating a Repository

1. **Access Gitea:**
   Open your Git server (e.g., `https://git.local.skill17.com`) and log in using your credentials.

2. **Choose a Framework Template:**
   Go to `organization -> frameworks` to pick a framework template for your repository. The templates include necessary Docker configurations and GitHub Actions workflows ready to use.

3. **Use the Template:**
   Click **"Use this template"** to create your repository. Name the repository to match the module name defined in the configuration file.
   - Example: If your module is `module-a`, name the repository `module-a`.

4. **Environment Setup:**
   The framework template automatically includes:
   - Dockerfile for containerization
   - GitHub Actions workflow for CI/CD
   - `.npmrc` with correct registry configuration (auto-replaced with your domain)
   - GitHub Actions secrets (USER, PASS, DOMAIN, NPM_REGISTRY_URL, SERVER_IP)

5. **Test the Setup:**
   Make a commit to verify that GitHub Actions are working correctly. The workflow should build and push your image to `git.domain/username/module_name:version`.

### Cloning and using the Repository

1. Clone the repository:
   ```bash
   git clone https://<username>:<password>@git.local.skill17.com/<username>/<module_name>.git
   cd <module_name>
   ```

2. Install dependencies (if using Node.js):
   ```bash
   npm install
   ```

3. Develop your code:
   - Edit, commit, and push frequently
   - Use branches for features/fixes
   - Always keep your README updated

4. Push your code:
   ```bash
   git push origin main
   ```
   This triggers the GitHub Actions workflow which builds your Docker image and pushes it to the registry.

## Troubleshooting

### Services not starting
- Check Docker is running: `docker ps`
- View logs: `docker compose -f docker/gitea.yaml logs`
- Use verbose mode: `./competition.sh -v init`

### Configuration issues
- Verify `config/main.json` is valid JSON: `jq . config/main.json`
- Check that `frameworks_repo` is accessible
- Ensure all required fields are present

### Cleaning up
- To reset everything: `./competition.sh clean`
- To stop without removing data: `./competition.sh stop`
- To restart: `./competition.sh start`
