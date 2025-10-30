# ============================================================================
# Stage 1: Build Stage - Compile the Qt application with static linking
# ============================================================================
FROM debian:trixie-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Chicago

# Install all build dependencies
RUN apt-get update && apt-get install -y \
    # Build tools
    build-essential \
    cmake \
    pkg-config \
    ninja-build \
    git \
    # Qt6 development packages
    qt6-base-dev \
    qt6-base-private-dev \
    qt6-declarative-dev \
    qt6-declarative-private-dev \
    qt6-tools-dev \
    qt6-tools-dev-tools \
    libqt6network6 \
    libqt6quick6 \
    libqt6core6t64 \
    libqt6gui6 \
    libqt6widgets6 \
    # Qt6 QML modules
    qml6-module-qtquick-dialogs \
    qml6-module-qtqml-workerscript \
    qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts \
    qml6-module-qtquick-window \
    qml6-module-qtquick \
    qml6-module-qtquick-templates \
    qml6-module-qt-labs-folderlistmodel \
    # OpenGL and graphics development libraries
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libegl1-mesa-dev \
    libgles2-mesa-dev \
    libglx-dev \
    libopengl-dev \
    # X11 development libraries
    libxkbcommon-dev \
    libxkbcommon-x11-dev \
    libx11-dev \
    libxext-dev \
    libxrender-dev \
    libxtst-dev \
    libxi-dev \
    libxrandr-dev \
    # Other development libraries
    libglib2.0-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libasound2-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy project files
COPY . .

# Remove any existing build directory and create fresh build directory
RUN rm -rf build_docker && \
    mkdir -p build_docker && \
    cd build_docker && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_PREFIX_PATH=/usr/lib/x86_64-linux-gnu/cmake/Qt6 \
        -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++" \
        -DQT_FEATURE_static_runtime=ON \
        -G Ninja && \
    ninja && \
    strip --strip-unneeded appDBC_Parser

    # ============================================================================
# Stage 1.5: Development Stage - For VS Code Dev Containers
# ============================================================================
FROM builder AS development

# Switch back to root to install additional tools
USER root

# Install additional development tools
RUN apt-get update && apt-get install -y \
    gdb \
    valgrind \
    vim \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Add dbcuser to sudoers
RUN useradd -m -s /bin/bash dbcuser && \
    usermod -aG audio,video dbcuser && \
    echo "dbcuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create workspace directory with proper permissions
RUN mkdir -p /workspaces && chown -R dbcuser:dbcuser /workspaces

WORKDIR /workspaces

# Switch to non-root user
USER dbcuser

# ============================================================================
# Stage 2: Runtime Stage - Minimal image for running the application
# ============================================================================
FROM debian:trixie-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Chicago
ENV DISPLAY=:0
ENV QT_QPA_PLATFORM=wayland;xcb
ENV QML_IMPORT_PATH=/usr/lib/x86_64-linux-gnu/qt6/qml
ENV QML2_IMPORT_PATH=/usr/lib/x86_64-linux-gnu/qt6/qml
ENV XDG_RUNTIME_DIR=/tmp
#ENV QT_XCB_GL_INTEGRATION=none


# Install only runtime dependencies (no development packages)
RUN apt-get update && apt-get install -y \
    # Qt6 runtime libraries (minimal set)
    libqt6core6t64 \
    libqt6gui6 \
    libqt6network6 \
    libqt6qml6 \
    libqt6quick6 \
    libqt6widgets6 \
    # Qt6 QML runtime modules
    qml6-module-qtquick \
    qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts \
    qml6-module-qtquick-window \
    qml6-module-qtquick-dialogs \
    qml6-module-qtquick-templates \
    qml6-module-qtqml-workerscript \
    qml6-module-qt-labs-folderlistmodel \
    # Minimal graphics and X11 runtime libraries
    libgl1 \
    libegl1 \
    libxkbcommon0 \
    libxkbcommon-x11-0 \
    libx11-6 \
    libxext6 \
    libxrender1 \
    libxi6 \
    libxrandr2 \
    # Wayland support for WSLg
    libwayland-client0 \
    libwayland-cursor0 \
    libwayland-egl1 \
    # Essential system libraries
    libglib2.0-0t64 \
    libfontconfig1 \
    libfreetype6 \
    libdbus-1-3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create non-root user
RUN useradd -m -s /bin/bash vscode && \
    usermod -aG audio,video vscode && \
    useradd -m -s /bin/bash dbcuser && \
    usermod -aG audio,video dbcuser

WORKDIR /app

# Copy only the compiled application and necessary files from builder
COPY --from=builder /app/build_docker/appDBC_Parser /app/
COPY --from=builder /app/*.qml /app/
COPY --from=builder /app/qmldir /app/
COPY --from=builder /app/*.dbc /app/
COPY --from=builder /app/*.json /app/
COPY --from=builder /app/start_app.sh /app/

# Make executable
RUN chmod +x /app/appDBC_Parser /app/start_app.sh && \
    chown -R dbcuser:dbcuser /app

# Switch to non-root user
USER dbcuser

# Set the entrypoint
ENTRYPOINT ["/app/start_app.sh"]

# Default command
CMD []
