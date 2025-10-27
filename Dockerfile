# Use Ubuntu 22.04 as the base image for better Qt6 support
FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Set display environment for GUI applications
ENV DISPLAY=:0
ENV QT_QPA_PLATFORM=xcb

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Build tools
    build-essential \
    cmake \
    pkg-config \
    ninja-build \
    # Qt6 core packages
    qt6-base-dev \
    qt6-declarative-dev \
    qt6-tools-dev \
    qt6-tools-dev-tools \
    libqt6network6 \
    libqt6quick6 \
    libqt6core6 \
    libqt6gui6 \
    libqt6widgets6 \
    # Qt6 additional modules for QML
    qml6-module-qtquick-dialogs \
    qml6-module-qtqml-workerscript \
    qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts \
    qml6-module-qtquick-window \
    qml6-module-qtquick \
    qml6-module-qtquick-templates \
    qml6-module-qt-labs-folderlistmodel \
    # OpenGL development packages (required for Qt6)
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libegl1-mesa-dev \
    libgles2-mesa-dev \
    libglx-dev \
    libopengl-dev \
    # XKB library for keyboard support
    libxkbcommon-dev \
    libxkbcommon-x11-dev \
    # X11 and graphics libraries for Qt GUI
    libx11-6 \
    libxext6 \
    libxrender1 \
    libxtst6 \
    libxi6 \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libfontconfig1 \
    libfreetype6 \
    libxss1 \
    libxrandr2 \
    libasound2 \
    libpangocairo-1.0-0 \
    libatk1.0-0 \
    libcairo-gobject2 \
    libgtk-3-0 \
    libgdk-pixbuf2.0-0 \
    # Network tools for debugging
    net-tools \
    iputils-ping \
    # Clean up
    && rm -rf /var/lib/apt/lists/*

# Try to install additional QML modules (these may not be available in all Ubuntu versions)
RUN apt-get update && \
    (apt-get install -y \
        qml6-module-qtquick-templates2 \
        qml6-module-qtquick-controls2 \
        qml6-module-qtquick-controls \
        qml6-module-qtqml-models \
        qml6-module-qtqml-workerscript2 \
        qml6-module-qt-labs-folderlistmodel \
        qml6-module-qtlabs-folderlistmodel \
        || echo "Some additional QML modules not available, continuing...") && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user for security
RUN useradd -m -s /bin/bash dbcuser && \
    usermod -aG audio,video dbcuser

# Set working directory
WORKDIR /app

# Copy project files
COPY --chown=dbcuser:dbcuser . .

# Create build directory
RUN mkdir -p build_docker && chown dbcuser:dbcuser build_docker

# Create a startup script (as root before switching users)
RUN echo '#!/bin/bash\n\
echo "Starting DBC Parser Application..."\n\
echo "Arguments: $@"\n\
\n\
# Check if we are running the server or GUI\n\
if [ "$1" = "server" ]; then\n\
    echo "Starting DBC Server..."\n\
    cd /app/build_docker\n\
    if [ -f "/app/DBCClient/server.conf" ]; then\n\
        echo "Using config: /app/DBCClient/server.conf"\n\
        exec ./dbc_server /app/DBCClient/server.conf\n\
    else\n\
        echo "No server configuration file found at /app/DBCClient/server.conf"\n\
        echo "Starting server with default settings..."\n\
        exec ./dbc_server\n\
    fi\n\
elif [ "$1" = "gui" ] || [ "$#" -eq 0 ]; then\n\
    echo "Starting GUI Application..."\n\
    echo "Display: $DISPLAY"\n\
    echo "Available displays:"\n\
    ls -la /tmp/.X11-unix/ 2>/dev/null || echo "No X11 sockets found"\n\
    echo "QML modules location:"\n\
    find /usr -name "*qtquick*" -type d 2>/dev/null | head -5 || echo "QML modules not found in standard locations"\n\
    echo "Running GUI application..."\n\
    cd /app/build_docker\n\
    exec ./appDBC_Parser\n\
else\n\
    echo "Unknown command: $1"\n\
    echo "Usage: $0 [server|gui]"\n\
    exit 1\n\
fi' > /app/start_app.sh && \
    chmod +x /app/start_app.sh && \
    chown dbcuser:dbcuser /app/start_app.sh

# Switch to non-root user
USER dbcuser

# Build the application
RUN cd build_docker && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_PREFIX_PATH=/usr/lib/aarch64-linux-gnu/cmake/Qt6 \
        -G Ninja && \
    ninja

# Expose the port for TCP server functionality
EXPOSE 12345

# Set the entrypoint
ENTRYPOINT ["/app/start_app.sh"]

# Default command
CMD []
