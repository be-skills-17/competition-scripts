#!/bin/bash

# Source logging for beautiful output
# SCRIPTS_DIR is exported by competition.sh
source "$SCRIPTS_DIR/logging.sh"

log_section "Installing Dependencies"

# Check if running with sudo privileges
if [ "$EUID" -ne 0 ]; then 
    log_error "This script must be run as root or with sudo"
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VERSION_CODENAME=${VERSION_CODENAME:-$(echo $VERSION | cut -d' ' -f1)}
else
    log_error "Cannot detect OS"
    exit 1
fi

log_info "Detected OS: $OS"

# Update package manager
log_subsection "Updating Package Manager"
apt update
log_success "Package manager updated"

# Install basic dependencies
log_subsection "Installing Basic Dependencies"
basic_deps="ca-certificates curl git sudo wget apt-transport-https gnupg lsb-release"
apt install -y $basic_deps
log_success "Basic dependencies installed"

# Install jq for JSON parsing
log_subsection "Installing jq"
apt install -y jq
log_success "jq installed"

# Install Docker
log_subsection "Installing Docker"

# Add Docker's official GPG key
log_info "Adding Docker GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
log_debug "Docker GPG key added"

# Add the repository to Apt sources
log_info "Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
log_debug "Docker repository added"

# Install Docker packages
log_info "Installing Docker packages..."
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
log_success "Docker installed"

# Setup Docker daemon
log_subsection "Configuring Docker"
systemctl enable docker
systemctl start docker
log_success "Docker daemon configured and started"

# Add current user to docker group (if not running as root)
if [ -n "$SUDO_USER" ]; then
    log_info "Adding $SUDO_USER to docker group..."
    usermod -aG docker "$SUDO_USER"
    log_success "$SUDO_USER added to docker group (may require logout/login)"
fi

# Install certbot for Let's Encrypt (optional but recommended)
log_subsection "Installing Certbot (Let's Encrypt)"
apt install -y certbot python3-certbot-dns-route53 || apt install -y certbot
log_success "Certbot installed"

# Install btop for system monitoring (optional but useful)
log_subsection "Installing System Tools"
apt install -y btop net-tools
log_success "System tools installed"

# Verify installations
log_section "Verifying Installations"

check_command() {
    if command -v "$1" &> /dev/null; then
        version=$($1 --version 2>&1 | head -n1)
        log_success "$1 installed: $version"
        return 0
    else
        log_error "$1 not found"
        return 1
    fi
}

check_command "docker"
check_command "jq"
check_command "git"
check_command "curl"
check_command "wget"

# Verify docker daemon is running
if docker ps > /dev/null 2>&1; then
    log_success "Docker daemon is running"
else
    log_warning "Docker daemon may not be running. Try: sudo systemctl start docker"
fi

echo ""
log_success "All dependencies installed successfully! 🎉"
echo ""
log_info "Next steps:"
echo "  1. Review config/main.json and customize settings"
echo "  2. Run: ./competition.sh init"
echo ""


