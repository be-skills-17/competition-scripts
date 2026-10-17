# Installation

## Quick Start

Get your system ready with a single command:

```bash
# Install all dependencies (Docker, jq, git, curl, etc.)
sudo ./competition.sh setup

# Configure your competition in config/main.json
# Then initialize the environment
sudo ./competition.sh init
```

## Prerequisites

The `setup` action automatically installs all required dependencies:
- **Docker** & **Docker Compose**
- **jq** - for JSON parsing
- **git** - for repository management
- **curl** - for API calls
- **wget** - for downloads
- **certbot** - for SSL certificates

If you prefer to install dependencies manually, see [Manual installation](#manual-installation).

## Manual Installation

If you prefer to install dependencies manually instead of using `sudo ./competition.sh setup`:

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
