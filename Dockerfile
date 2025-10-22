# syntax=docker/dockerfile:1

# Build stage for Linux
FROM ubuntu:22.04 AS builder-linux
ARG DEBIAN_FRONTEND=noninteractive

# Install Qt and build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    qt6-base-dev \
    qt6-tools-dev \
    qt6-tools-dev-tools \
    libgl1-mesa-dev \
    libxkbcommon-x11-0 \
    libxcb-xinerama0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY . .

# Build the application
RUN mkdir -p build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    cmake --build . --parallel $(nproc)

# Runtime stage for Linux
FROM ubuntu:22.04 AS runtime-linux
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    libqt6core6 \
    libqt6gui6 \
    libqt6widgets6 \
    libgl1 \
    libxkbcommon-x11-0 \
    libxcb-xinerama0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder-linux /build/build/your-app /app/

# Create a non-root user
RUN useradd -m -u 1000 qtuser && chown -R qtuser:qtuser /app
USER qtuser

ENTRYPOINT ["/app/your-app"]


# Build stage for Windows (using Wine for cross-compilation)
FROM ubuntu:22.04 AS builder-windows
ARG DEBIAN_FRONTEND=noninteractive

# Install MinGW and Qt for Windows cross-compilation
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    mingw-w64 \
    wine64 \
    wget \
    p7zip-full \
    && rm -rf /var/lib/apt/lists/*

# Download and install Qt for Windows (MXE or custom Qt build)
WORKDIR /opt
RUN wget https://download.qt.io/official_releases/qt/6.5/6.5.3/single/qt-everywhere-src-6.5.3.tar.xz && \
    tar xf qt-everywhere-src-6.5.3.tar.xz && \
    rm qt-everywhere-src-6.5.3.tar.xz

# Note: This is simplified - you'd need to properly build Qt for MinGW
# Or use pre-built MXE packages

WORKDIR /build
COPY . .

# Cross-compile for Windows
RUN mkdir -p build-win && cd build-win && \
    cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=../cmake/mingw-w64-x86_64.cmake \
    -DCMAKE_BUILD_TYPE=Release && \
    cmake --build . --parallel $(nproc)

# Runtime stage for Windows
FROM mcr.microsoft.com/windows/servercore:ltsc2022 AS runtime-windows

WORKDIR /app
COPY --from=builder-windows /build/build-win/your-app.exe /app/
COPY --from=builder-windows /build/build-win/*.dll /app/

ENTRYPOINT ["C:\\app\\your-app.exe"]