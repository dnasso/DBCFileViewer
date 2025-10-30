
#!/bin/bash

# DBC Parser Docker Setup Script
# This script helps set up and run the DBC Parser application in Docker

# Docker image name
DBC_PARSER_IMAGE="dbcfileviewer:latest"

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

# Function to detect if running in WSL
detect_wsl() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        print_success "Running in WSL environment"
        export IS_WSL=true
        
        # Check for WSLg
        if [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; then
            print_success "WSLg GUI support detected"
            export HAS_WSLG=true
        else
            print_warning "WSLg not detected. Make sure you're running Windows 11 or WSL with GUI support"
            export HAS_WSLG=false
        fi
    else
        export IS_WSL=false
        export HAS_WSLG=false
    fi
}

# Function to set up Wayland forwarding for GUI
setup_wayland() {
    print_info "Checking for Wayland support..."
    
    # Check if Wayland is running
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then
        print_success "Wayland detected: $WAYLAND_DISPLAY"
        WAYLAND_SOCKET_PATH=""
        
        # Check common Wayland socket locations (including WSLg)
        if [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/${WAYLAND_DISPLAY}" ]; then
            WAYLAND_SOCKET_PATH="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/${WAYLAND_DISPLAY}"
            print_success "Wayland socket found: $WAYLAND_SOCKET_PATH"
        elif [ -S "/mnt/wslg/runtime-dir/${WAYLAND_DISPLAY}" ]; then
            # WSLg socket location
            WAYLAND_SOCKET_PATH="/mnt/wslg/runtime-dir/${WAYLAND_DISPLAY}"
            print_success "WSLg Wayland socket found: $WAYLAND_SOCKET_PATH"
        elif [ -S "/tmp/${WAYLAND_DISPLAY}" ]; then
            WAYLAND_SOCKET_PATH="/tmp/${WAYLAND_DISPLAY}"
            print_success "Wayland socket found: $WAYLAND_SOCKET_PATH"
        else
            print_warning "Wayland socket not found in standard locations"
        fi
        
        export WAYLAND_SOCKET_PATH
        return 0
    else
        print_info "Wayland not detected (WAYLAND_DISPLAY not set)"
        return 1
    fi
}

# Function to setup display forwarding (both X11 and Wayland)
setup_display() {
    print_info "Setting up display forwarding..."
    
    # Detect WSL first
    detect_wsl
    
    local has_x11=false
    local has_wayland=false
    
    setup_x11 && has_x11=true || has_x11=false
    setup_wayland && has_wayland=true || has_wayland=false
    
    if $has_wayland && $has_x11; then
        export QT_QPA_PLATFORM="wayland;xcb"
        print_success "Both Wayland and X11 available - Qt will use Wayland with X11 fallback"
    elif $has_wayland; then
        export QT_QPA_PLATFORM="wayland"
        print_success "Using Wayland for display"
    elif $has_x11; then
        export QT_QPA_PLATFORM="xcb"
        print_success "Using X11 for display"
    else
        export QT_QPA_PLATFORM="offscreen"
        print_warning "No display server detected - GUI may not work!"
        
        if [ "$IS_WSL" = true ]; then
            print_warning "Make sure you're running Windows 11 with WSLg support"
            print_info "Try: wsl --shutdown (in PowerShell) then restart WSL"
        fi
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
        $docker_cmd build --no-cache -t $DBC_PARSER_IMAGE .
    else
        $docker_cmd build -t $DBC_PARSER_IMAGE .
    fi
    
    print_success "Docker image built successfully"
}

# Function to run the application using Docker Compose
run_with_compose() {
    print_info "Starting DBC Parser with integrated server using Docker Compose..."
    
    # Ensure log and config directories exist
    mkdir -p logs config
    
    # Set the DISPLAY environment variable if not set
    export DISPLAY=${DISPLAY:-:0}
    
    # Setup display forwarding
    setup_display
    
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
    
    # Setup display forwarding
    setup_display
    
    # Build Docker run command with display forwarding
    local docker_cmd="docker run -it --rm \
        --name dbc-parser-app"
    
    # Add X11 socket if available
    if [ -d /tmp/.X11-unix ]; then
        docker_cmd="$docker_cmd -v /tmp/.X11-unix:/tmp/.X11-unix:rw"
    fi
    
    # Add Wayland socket if available
    if [ -n "${WAYLAND_SOCKET_PATH:-}" ] && [ -S "$WAYLAND_SOCKET_PATH" ]; then
        local socket_name=$(basename "$WAYLAND_SOCKET_PATH")
        docker_cmd="$docker_cmd -v $WAYLAND_SOCKET_PATH:/tmp/$socket_name:rw"
        docker_cmd="$docker_cmd -e WAYLAND_DISPLAY=$socket_name"
    fi
    
    # Add WSL GPU support if available
    if [ "$IS_WSL" = true ] && [ -d /usr/lib/wsl ]; then
        print_info "Adding WSL GPU support"
        docker_cmd="$docker_cmd -v /usr/lib/wsl:/usr/lib/wsl:ro"
        docker_cmd="$docker_cmd -e LD_LIBRARY_PATH=/usr/lib/wsl/lib"
        if [ -c /dev/dxg ]; then
            docker_cmd="$docker_cmd --device=/dev/dxg"
        fi
    fi
    
    # Add common volume mounts and environment variables
    docker_cmd="$docker_cmd \
        -v $(pwd)/logs:/app/logs:rw \
        -v $(pwd)/config:/app/config:rw \
        -v $(pwd):/workspaces/DBCFileViewer:cached \
        -e DISPLAY=$DISPLAY \
        -e QT_QPA_PLATFORM=${QT_QPA_PLATFORM:-xcb} \
        -e XDG_RUNTIME_DIR=/tmp \
        -e QT_XCB_GL_INTEGRATION=none \
        --security-opt seccomp=unconfined \
        --network host \
        $DBC_PARSER_IMAGE"
    
    print_info "Running: $docker_cmd"
    eval $docker_cmd
    
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
    docker rmi $DBC_PARSER_IMAGE 2>/dev/null || true
    
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
        setup_display
        run_with_compose
        ;;
    "run-gui-only")
        check_docker
        setup_display
        print_info "Starting DBC Parser GUI only..."
        mkdir -p logs config
        
        # Build Docker run command
        local docker_cmd="docker run -it --rm \
            --name dbc-gui-only"
        
        # Add X11 socket if available
        if [ -d /tmp/.X11-unix ]; then
            docker_cmd="$docker_cmd -v /tmp/.X11-unix:/tmp/.X11-unix:rw"
        fi
        
        # Add Wayland socket if available
        if [ -n "${WAYLAND_SOCKET_PATH:-}" ] && [ -S "$WAYLAND_SOCKET_PATH" ]; then
            local socket_name=$(basename "$WAYLAND_SOCKET_PATH")
            docker_cmd="$docker_cmd -v $WAYLAND_SOCKET_PATH:/tmp/$socket_name:rw"
            docker_cmd="$docker_cmd -e WAYLAND_DISPLAY=$socket_name"
        fi
        
        docker_cmd="$docker_cmd \
            -v $(pwd)/logs:/app/logs:rw \
            -v $(pwd)/config:/app/config:rw \
            -v $(pwd):/workspaces/DBCFileViewer:cached \
            -e DISPLAY=${DISPLAY:-:0} \
            -e QT_QPA_PLATFORM=${QT_QPA_PLATFORM:-xcb} \
            -e XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)} \
            --network host \
            $DBC_PARSER_IMAGE"
        
        eval $docker_cmd
        ;;
    "run-docker")
        check_docker
        setup_display
        run_with_docker
        ;;
    "setup")
        check_docker
        check_docker_compose
        setup_display
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
