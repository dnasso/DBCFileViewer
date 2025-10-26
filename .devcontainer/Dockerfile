FROM debian:bookworm AS builder

ARG DEBIAN_FRONTEND=noninteractive

# Base tooling and Qt6 dev packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    ninja-build \
    git \
    gdb \
    pkg-config \
    ca-certificates \
    sudo \
    locales \
    # Qt6 dev (base + declarative + tools)
    qt6-base-dev \
    qt6-declarative-dev \
    qt6-tools-dev \
    qt6-tools-dev-tools \
    qt6-wayland \
    # X11/OpenGL runtime deps for running the app inside the container
    libgl1-mesa-dri \
    mesa-utils \
    libgl1 \
    libopengl0 \
    libglx0 \
    libegl1 \
    libxkbcommon0 \
    libxkbcommon-x11-0 \
    libxkbcommon-dev \
    libxcb-xinerama0 \
    libxcb-cursor0 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-randr0 \
    libxcb-render-util0 \
    libxcb-shape0 \
    libxcb-sync1 \
    libxcb-xfixes0 \
    libfontconfig1 \
    libdbus-1-3 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Locale
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
 && locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Non-root user (to match VS Code devcontainers convention)
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupadd --gid ${USER_GID} ${USERNAME} \
 && useradd -s /bin/bash --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
 && chmod 0440 /etc/sudoers.d/${USERNAME}

# Set up environment helpful for Qt apps
ENV QT_QPA_PLATFORM=xcb \
    QSG_RENDER_LOOP=basic \
    LIBGL_ALWAYS_INDIRECT=0

WORKDIR /workspaces/DBCFileViewer
USER ${USERNAME}

# Default shell
CMD ["bash"]

