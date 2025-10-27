# DBC Parser Docker Guide

This guide explains how to build and run the DBC Parser application in a Docker container on Linux systems.

## Prerequisites

### System Requirements
- Linux distribution (Ubuntu 18.04+, CentOS 7+, or equivalent)
- Docker Engine 20.10+
- Docker Compose 1.27+ (or Docker Compose V2)
- X11 display server (for GUI applications)
- At least 2GB RAM
- At least 1GB free disk space

### Install Docker

#### Ubuntu/Debian:
```bash
# Update package index
sudo apt-get update

# Install Docker
sudo apt-get install -y docker.io docker-compose

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add your user to docker group (logout/login required)
sudo usermod -aG docker $USER
```

#### CentOS/RHEL/Fedora:
```bash
# Install Docker
sudo yum install -y docker docker-compose
# OR for newer versions:
sudo dnf install -y docker docker-compose

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add your user to docker group
sudo usermod -aG docker $USER
```

#### Arch Linux:
```bash
# Install Docker
sudo pacman -S docker docker-compose

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add your user to docker group
sudo usermod -aG docker $USER
```

### Install X11 Dependencies (for GUI)
```bash
# Ubuntu/Debian
sudo apt-get install -y xorg-dev x11-xserver-utils

# CentOS/RHEL/Fedora
sudo yum install -y xorg-x11-server-utils
# OR
sudo dnf install -y xorg-x11-server-utils

# Arch Linux
sudo pacman -S xorg-server xorg-xhost
```

## Quick Start

1. **Navigate to the project directory:**
   ```bash
   cd "path/to/your/Senior Project main"
   ```

2. **Run the setup script:**
   ```bash
   # Make sure the script is executable
   chmod +x docker-setup.sh
   
   # Run initial setup
   ./docker-setup.sh setup
   ```

3. **Build the Docker image:**
   ```bash
   ./docker-setup.sh build
   ```

4. **Run the application:**
   ```bash
   ./docker-setup.sh run
   ```

## Detailed Instructions

### Method 1: Using Docker Compose (Recommended)

1. **Build the image:**
   ```bash
   docker build -t dbc-parser:latest .
   ```

2. **Start the application:**
   ```bash
   # Allow X11 forwarding
   xhost +local:
   
   # Start with Docker Compose
   docker-compose up -d
   ```

3. **View logs:**
   ```bash
   docker-compose logs -f
   ```

4. **Stop the application:**
   ```bash
   docker-compose down
   ```

### Method 2: Using Docker Run

1. **Build the image:**
   ```bash
   docker build -t dbc-parser:latest .
   ```

2. **Run the container:**
   ```bash
   # Allow X11 forwarding
   xhost +local:
   
   # Run the container
   docker run -it --rm \
     --name dbc-parser-app \
     -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
     -v "$(pwd)/logs:/app/logs:rw" \
     -v "$(pwd)/config:/app/config:rw" \
     -e DISPLAY="$DISPLAY" \
     -e QT_QPA_PLATFORM=xcb \
     --network host \
     --user "$(id -u):$(id -g)" \
     dbc-parser:latest
   ```

## Script Usage

The provided `docker-setup.sh` script simplifies common operations:

```bash
# Setup and check dependencies
./docker-setup.sh setup

# Build the Docker image
./docker-setup.sh build

# Build without cache (for clean builds)
./docker-setup.sh build --no-cache

# Run using Docker Compose (recommended)
./docker-setup.sh run

# Run using Docker directly
./docker-setup.sh run-docker

# Stop the application
./docker-setup.sh stop

# View application logs
./docker-setup.sh logs

# Clean up Docker resources
./docker-setup.sh clean

# Show help
./docker-setup.sh help
```

## Troubleshooting

### GUI Not Displaying

1. **Check X11 forwarding:**
   ```bash
   echo $DISPLAY
   xhost +local:
   ```

2. **Install X11 dependencies:**
   ```bash
   # Ubuntu/Debian
   sudo apt-get install x11-xserver-utils
   
   # CentOS/RHEL
   sudo yum install xorg-x11-server-utils
   ```

3. **For SSH connections:**
   ```bash
   ssh -X username@hostname
   ```

### Permission Issues

1. **Add user to docker group:**
   ```bash
   sudo usermod -aG docker $USER
   # Logout and login again
   ```

2. **Fix X11 permissions:**
   ```bash
   xhost +local:docker
   ```

### Build Failures

1. **Clean build (no cache):**
   ```bash
   ./docker-setup.sh build --no-cache
   ```

2. **Check disk space:**
   ```bash
   df -h
   docker system df
   ```

3. **Clean Docker resources:**
   ```bash
   ./docker-setup.sh clean
   ```

### Network Issues

1. **Check if port 12345 is available:**
   ```bash
   netstat -tulpn | grep 12345
   ```

2. **Use different network mode:**
   ```bash
   # Edit docker-compose.yml and change:
   network_mode: bridge
   ports:
     - "12345:12345"
   ```

### Application Crashes

1. **Check logs:**
   ```bash
   ./docker-setup.sh logs
   ```

2. **Run in interactive mode:**
   ```bash
   docker run -it --rm \
     -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
     -e DISPLAY="$DISPLAY" \
     --network host \
     dbc-parser:latest /bin/bash
   ```

## File Structure

After running the application, the following directories will be created:

```
.
├── logs/           # Application logs
├── config/         # Configuration files
├── Dockerfile      # Docker build instructions
├── docker-compose.yml  # Docker Compose configuration
├── docker-setup.sh # Setup and management script
└── .dockerignore   # Files to ignore during build
```

## Network Configuration

The application exposes port **12345** for TCP server functionality. This port is automatically configured when using the provided Docker setup.

## Security Notes

- The container runs as a non-root user for security
- X11 socket is mounted read-write for GUI functionality
- Network access is limited to necessary ports
- No sensitive data is stored in the container

## Performance Tips

1. **Increase Docker resources:**
   - Allocate more RAM (2GB minimum)
   - Ensure sufficient CPU cores

2. **Use SSD storage for better I/O performance**

3. **Clean up unused Docker resources periodically:**
   ```bash
   docker system prune -f
   ```

## Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review application logs: `./docker-setup.sh logs`
3. Ensure all prerequisites are installed
4. Try rebuilding the image: `./docker-setup.sh build --no-cache`
