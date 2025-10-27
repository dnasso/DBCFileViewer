#!/bin/bash

# Native Build Script for DBC Parser
# This script builds and runs the DBC Parser application natively on Linux

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

# Function to check if Qt6 is installed
check_qt6() {
    print_info "Checking Qt6 installation..."
    
    if ! command -v qmake6 &> /dev/null && ! command -v qmake &> /dev/null; then
        print_error "Qt6 is not installed or not in PATH"
        print_info "Please install Qt6 development packages:"
        print_info "Ubuntu/Debian: sudo apt install qt6-base-dev qt6-declarative-dev"
        print_info "Fedora: sudo dnf install qt6-qtbase-devel qt6-qtdeclarative-devel"
        exit 1
    fi
    
    # Try to find Qt6 cmake files
    QT6_PATHS=(
        "/usr/lib/aarch64-linux-gnu/cmake/Qt6"
        "/usr/lib/x86_64-linux-gnu/cmake/Qt6"
        "/usr/lib64/cmake/Qt6"
        "/usr/lib/cmake/Qt6"
        "/usr/share/cmake/Qt6"
        "/opt/qt6/lib/cmake/Qt6"
    )
    
    QT6_CMAKE_PATH=""
    for path in "${QT6_PATHS[@]}"; do
        if [ -d "$path" ]; then
            QT6_CMAKE_PATH="$path"
            break
        fi
    done
    
    if [ -z "$QT6_CMAKE_PATH" ]; then
        print_warning "Qt6 CMake files not found in standard locations"
        print_info "Will try to build without explicit Qt6 path"
    else
        print_success "Found Qt6 at: $QT6_CMAKE_PATH"
    fi
}

# Function to check dependencies
check_dependencies() {
    print_info "Checking build dependencies..."
    
    # Check for cmake
    if ! command -v cmake &> /dev/null; then
        print_error "CMake is not installed"
        print_info "Install with: sudo apt install cmake (Ubuntu) or sudo dnf install cmake (Fedora)"
        exit 1
    fi
    
    # Check for build tools
    if ! command -v gcc &> /dev/null && ! command -v clang &> /dev/null; then
        print_error "No C++ compiler found"
        print_info "Install with: sudo apt install build-essential (Ubuntu) or sudo dnf install gcc-c++ (Fedora)"
        exit 1
    fi
    
    print_success "Build dependencies are available"
}

# Function to clean build directory
clean_build() {
    print_info "Cleaning build directory..."
    rm -rf build_native
    mkdir -p build_native
    print_success "Build directory cleaned"
}

# Function to build the project
build_project() {
    print_info "Building DBC Parser..."
    
    # Create build directory if it doesn't exist
    mkdir -p build_native
    cd build_native
    
    # Configure with CMake
    if [ -n "$QT6_CMAKE_PATH" ]; then
        cmake .. \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_PREFIX_PATH="$QT6_CMAKE_PATH" \
            -G "Unix Makefiles"
    else
        cmake .. \
            -DCMAKE_BUILD_TYPE=Release \
            -G "Unix Makefiles"
    fi
    
    # Build
    make -j$(nproc)
    
    cd ..
    print_success "Build completed successfully"
}

# Function to create config files
setup_config() {
    print_info "Setting up configuration files..."
    
    # Create server config if it doesn't exist
    if [ ! -f "DBCClient/server.conf" ]; then
        mkdir -p DBCClient
        echo "port=12345" > DBCClient/server.conf
        print_info "Created server configuration file"
    fi
    
    # Create logs directory
    mkdir -p logs
    
    print_success "Configuration setup completed"
}

# Function to run the server
run_server() {
    print_info "Starting DBC Server..."
    
    if [ ! -f "build_native/dbc_server" ]; then
        print_error "Server executable not found. Please build first."
        exit 1
    fi
    
    cd build_native
    ./dbc_server ../DBCClient/server.conf
}

# Function to run the GUI
run_gui() {
    print_info "Starting DBC Parser GUI..."
    
    if [ ! -f "build_native/appDBC_Parser" ]; then
        print_error "GUI executable not found. Please build first."
        exit 1
    fi
    
    cd build_native
    ./appDBC_Parser
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  deps           Check and install dependencies"
    echo "  build          Build the project"
    echo "  clean          Clean build directory and rebuild"
    echo "  run-server     Run the DBC server"
    echo "  run-gui        Run the DBC parser GUI"
    echo "  run            Run both server (background) and GUI"
    echo "  help           Show this help message"
    echo ""
    echo "Quick start:"
    echo "  $0 deps && $0 build && $0 run"
}

# Main script logic
case "$1" in
    "deps")
        check_dependencies
        check_qt6
        ;;
    "build")
        check_dependencies
        check_qt6
        setup_config
        build_project
        ;;
    "clean")
        check_dependencies
        check_qt6
        clean_build
        setup_config
        build_project
        ;;
    "run-server")
        run_server
        ;;
    "run-gui")
        run_gui
        ;;
    "run")
        print_info "Starting DBC Parser with integrated server..."
        setup_config
        
        # Start server in background
        if [ -f "build_native/dbc_server" ]; then
            print_info "Starting server in background..."
            cd build_native
            ./dbc_server ../DBCClient/server.conf &
            SERVER_PID=$!
            cd ..
            sleep 2
            print_success "Server started with PID $SERVER_PID"
        else
            print_warning "Server executable not found, starting GUI only"
        fi
        
        # Start GUI
        if [ -f "build_native/appDBC_Parser" ]; then
            print_info "Starting GUI application..."
            cd build_native
            ./appDBC_Parser
            # Kill server when GUI exits
            if [ -n "$SERVER_PID" ]; then
                print_info "Stopping server..."
                kill $SERVER_PID 2>/dev/null || true
            fi
        else
            print_error "GUI executable not found. Please build first."
            exit 1
        fi
        ;;
    "help"|"--help"|"-h")
        show_usage
        ;;
    "")
        print_info "DBC Parser Native Build Script"
        show_usage
        ;;
    *)
        print_error "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac
