# Installing Docker

This guide covers installing Docker on various operating systems. Docker Desktop includes Docker Compose, which is required for running GridAPPS-D.

## Quick Links

- [Ubuntu / Debian](#ubuntu--debian)
- [Fedora / RHEL / CentOS](#fedora--rhel--centos)
- [macOS](#macos)
- [Windows](#windows)
- [Verify Installation](#verify-installation)

---

## Ubuntu / Debian

### Option 1: Docker Desktop (Recommended for desktop use)

1. Download Docker Desktop from [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/)
2. Install the `.deb` package:
   ```bash
   sudo apt install ./docker-desktop-<version>-amd64.deb
   ```
3. Start Docker Desktop from your applications menu

### Option 2: Docker Engine (Recommended for servers)

Follow Docker's official installation guide: [docs.docker.com/engine/install/ubuntu](https://docs.docker.com/engine/install/ubuntu/)

Quick summary:
```bash
# Remove old versions
sudo apt-get remove docker docker-engine docker.io containerd runc

# Set up Docker's apt repository
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add your user to the docker group (to run without sudo)
sudo usermod -aG docker $USER
```

**Important:** Log out and back in for the group change to take effect.

---

## Fedora / RHEL / CentOS

### Docker Engine

Follow Docker's official installation guide: [docs.docker.com/engine/install/fedora](https://docs.docker.com/engine/install/fedora/)

Quick summary for Fedora:
```bash
# Remove old versions
sudo dnf remove docker docker-client docker-client-latest docker-common \
    docker-latest docker-latest-logrotate docker-logrotate docker-engine

# Set up the repository
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo

# Install Docker Engine
sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add your user to the docker group
sudo usermod -aG docker $USER
```

**Important:** Log out and back in for the group change to take effect.

---

## macOS

### Docker Desktop (Recommended)

1. Download Docker Desktop from [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/)
2. Open the `.dmg` file and drag Docker to Applications
3. Start Docker Desktop from Applications
4. Follow the setup wizard

### Using Homebrew

```bash
brew install --cask docker
```

Then start Docker Desktop from Applications.

---

## Windows

### Docker Desktop (Recommended)

1. **Prerequisites:**
   - Windows 10 64-bit: Pro, Enterprise, or Education (Build 19041 or higher)
   - Windows 11 64-bit
   - WSL 2 enabled (Docker Desktop will prompt you to enable it)

2. Download Docker Desktop from [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/)

3. Run the installer and follow the prompts

4. After installation, start Docker Desktop

5. When prompted, enable WSL 2 integration

### Using WSL 2

If you prefer running GridAPPS-D in WSL 2:

1. Install a Linux distribution from the Microsoft Store (Ubuntu recommended)
2. Follow the [Ubuntu / Debian](#ubuntu--debian) instructions inside WSL 2
3. Enable WSL 2 integration in Docker Desktop settings

---

## Verify Installation

After installation, verify Docker is working:

```bash
# Check Docker version
docker --version

# Check Docker Compose version (plugin style)
docker compose version

# Or standalone (older installations)
docker-compose --version

# Test Docker is running
docker run hello-world
```

You should see output similar to:
```
Docker version 24.0.x, build xxxxxxx
Docker Compose version v2.x.x
```

## Troubleshooting

### Permission denied errors

If you get "permission denied" errors:
```bash
sudo usermod -aG docker $USER
```
Then log out and back in.

### Docker daemon not running

```bash
# Linux
sudo systemctl start docker

# macOS/Windows
# Start Docker Desktop from your applications
```

### WSL 2 issues on Windows

See Docker's WSL 2 troubleshooting guide: [docs.docker.com/desktop/wsl](https://docs.docker.com/desktop/wsl/)

---

## Next Steps

Once Docker is installed and running:

```bash
cd gridappsd-docker
./run.sh
```

See the main [README.md](README.md) for usage instructions.
