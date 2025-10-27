#!/bin/bash

# DBC Parser Docker Setup Script
# This script helps set up and run the DBC Parser application in Docker

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        print_info "Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    # Try docker info without sudo first, then with sudo
    if ! docker info &> /dev/null; then
        if sudo docker info &> /dev/null; then
            print_warning "Docker requires sudo. Adding user to docker group..."
            sudo usermod -aG docker $USER
            print_info "User added to docker group. Please logout and login again, or run: newgrp docker"
            print_info "For now, continuing with sudo..."
            USE_SUDO=true
        else
            print_error "Docker daemon is not running. Please start Docker with: sudo systemctl start docker"
            exit 1
        fi
    else
        print_success "Docker is installed and running"
        USE_SUDO=false
    fi
}

# Function to check if Docker Compose is installed
check_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        print_warning "docker-compose not found, trying docker compose..."
        if ! docker compose version &> /dev/null; then
            print_error "Docker Compose is not installed. Please install Docker Compose."
            print_info "Visit: https://docs.docker.com/compose/install/"
            exit 1
        else
            COMPOSE_CMD="docker compose"
        fi
    else
        COMPOSE_CMD="docker-compose"
    fi
    
    print_success "Docker Compose is available"
}

# Function to set up X11 forwarding for GUI
setup_x11() {
    print_info "Setting up X11 forwarding for GUI applications..."
    
    # Allow local connections to X server
    if command -v xhost &> /dev/null; then
        xhost +local: || print_warning "Could not run xhost. GUI may not work properly."
        print_success "X11 forwarding configured"
    else
        print_warning "xhost not found. Install xorg-x11-server-utils or equivalent package for GUI support."
    fi
}

# Function to build the Docker image
build_image() {
    print_info "Building DBC Parser Docker image..."
    
    local docker_cmd="docker"
    if [ "$USE_SUDO" = "true" ]; then
        docker_cmd="sudo docker"
    fi
    
    if [ "$1" = "--no-cache" ]; then
        $docker_cmd build --no-cache -t dbc-parser:latest .
    else
        $docker_cmd build -t dbc-parser:latest .
    fi
    
    print_success "Docker image built successfully"
}

# Function to run the application using Docker Compose
run_with_compose() {
    print_info "Starting DBC Parser with integrated server using Docker Compose..."
    
    # Ensure log and config directories exist
    mkdir -p logs config
    
    # Create server config if it doesn't exist
    if [ ! -f "DBCClient/server.conf" ]; then
        print_info "Creating default server configuration..."
        mkdir -p DBCClient
        echo "port=12345" > DBCClient/server.conf
    fi
    
    # Set the DISPLAY environment variable if not set
    export DISPLAY=${DISPLAY:-:0}
    
    # Use sudo if needed for Docker Compose
    local compose_cmd="$COMPOSE_CMD"
    if [ "$USE_SUDO" = "true" ]; then
        compose_cmd="sudo $COMPOSE_CMD"
    fi
    
    $compose_cmd up -d
    print_success "DBC Parser and Server started with Docker Compose"
    print_info "Server running on port 12345"
    print_info "GUI will connect to server automatically"
    print_info "Use '$compose_cmd logs -f dbc-server' to view server logs"
    print_info "Use '$compose_cmd logs -f dbc-parser-gui' to view GUI logs"
    print_info "Use '$compose_cmd down' to stop all services"
}

# Function to run the application directly with Docker
run_with_docker() {
    print_info "Starting DBC Parser using Docker run..."
    
    # Ensure log and config directories exist
    mkdir -p logs config
    
    # Set the DISPLAY environment variable if not set
    export DISPLAY=${DISPLAY:-:0}
    
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
    
    print_success "DBC Parser started with Docker run"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  build          Build the Docker image"
    echo "  build --no-cache    Build the Docker image without cache"
    echo "  run            Run both GUI and Server using Docker Compose (recommended)"
    echo "  run-gui-only   Run only the GUI application"
    echo "  run-server-only Run only the TCP server"
    echo "  run-docker     Run using docker run command"
    echo "  setup          Initial setup (check dependencies, setup X11)"
    echo "  stop           Stop the running application"
    echo "  logs           Show application logs"
    echo "  clean          Remove Docker image and containers"
    echo "  help           Show this help message"
}

# Function to stop the application
stop_app() {
    print_info "Stopping DBC Parser application..."
    
    # Check and set compose command
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    fi
    
    # Stop compose services if available
    if [ -n "$COMPOSE_CMD" ]; then
        $COMPOSE_CMD down 2>/dev/null || true
    fi
    
    # Stop any running containers
    docker stop dbc-parser-app dbc-server-only dbc-gui-only 2>/dev/null || true
    docker rm dbc-parser-app dbc-server-only dbc-gui-only 2>/dev/null || true
    
    print_success "Application stopped"
}

# Function to show logs
show_logs() {
    # Check and set compose command
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    fi
    
    if [ -n "$COMPOSE_CMD" ]; then
        $COMPOSE_CMD logs -f
    else
        docker logs -f dbc-parser-app 2>/dev/null || print_error "No running container found"
    fi
}

# Function to clean up Docker resources
clean_up() {
    print_info "Cleaning up Docker resources..."
    
    # Stop and remove containers
    stop_app
    
    # Remove image
    docker rmi dbc-parser:latest 2>/dev/null || true
    
    # Remove unused Docker resources
    docker system prune -f
    
    print_success "Cleanup completed"
}

# Main script logic
case "$1" in
    "build")
        check_docker
        build_image "$2"
        ;;
    "run")
        check_docker
        check_docker_compose
        setup_x11
        run_with_compose
        ;;
    "run-server-only")
        check_docker
        print_info "Starting DBC Server only..."
        mkdir -p logs config DBCClient
        if [ ! -f "DBCClient/server.conf" ]; then
            echo "port=12345" > DBCClient/server.conf
        fi
        docker run -d --rm \
            --name dbc-server-only \
            -v "$(pwd)/logs:/app/logs:rw" \
            -v "$(pwd)/config:/app/config:rw" \
            -v "$(pwd)/DBCClient:/app/DBCClient:ro" \
            -p 12345:12345 \
            dbc-parser:latest server /app/DBCClient/server.conf
        print_success "DBC Server started on port 12345"
        ;;
    "run-gui-only")
        check_docker
        setup_x11
        print_info "Starting DBC Parser GUI only..."
        mkdir -p logs config
        docker run -it --rm \
            --name dbc-gui-only \
            -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
            -v "$(pwd)/logs:/app/logs:rw" \
            -v "$(pwd)/config:/app/config:rw" \
            -e DISPLAY="$DISPLAY" \
            -e QT_QPA_PLATFORM=xcb \
            --network host \
            --user "$(id -u):$(id -g)" \
            dbc-parser:latest
        ;;
    "run-docker")
        check_docker
        setup_x11
        run_with_docker
        ;;
    "setup")
        check_docker
        check_docker_compose
        setup_x11
        print_success "Setup completed"
        ;;
    "stop")
        stop_app
        ;;
    "logs")
        show_logs
        ;;
    "clean")
        clean_up
        ;;
    "help"|"--help"|"-h")
        show_usage
        ;;
    "")
        print_info "DBC Parser Docker Setup"
        print_info "Run '$0 help' for usage information"
        print_info "Quick start: '$0 setup && $0 build && $0 run'"
        ;;
    *)
        print_error "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac
