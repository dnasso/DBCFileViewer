cmake_minimum_required(VERSION 3.16)
project(DBC_Parser VERSION 0.1 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Add Network component for TCP functionality in Qtclient.cpp
find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Network)

# Qt6.2 compatible setup (qt_standard_project_setup requires Qt6.5+)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Cross-compilation option for server.cpp
option(CROSS_COMPILE_SERVER "Cross-compile server.cpp for Linux from Windows" OFF)

# Define source files based on platform
set(COMMON_SOURCES
    main.cpp
    DbcParser.cpp
    DbcSender.cpp
    ./DBCClient/Qtclient.cpp
)

# Handle server.cpp compilation - create separate executable
if(UNIX AND NOT APPLE)
    # Don't add server.cpp to COMMON_SOURCES, create separate executable instead
    message(STATUS "Will create separate server executable for Linux build")
elseif(WIN32 AND DEFINED ENV{WSL_DISTRO_NAME})
    # We're in WSL - treat as Linux
    message(STATUS "Will create separate server executable for WSL build")
elseif(WIN32 AND CROSS_COMPILE_SERVER)
    # Cross-compile server.cpp for Linux on Windows
    find_program(LINUX_GCC NAMES x86_64-linux-gnu-gcc x86_64-linux-gnu-g++)
    if(LINUX_GCC)
        message(STATUS "Cross-compiling server.cpp for Linux using: ${LINUX_GCC}")
        # Create custom target to cross-compile server.cpp
        add_custom_command(
            OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/server_linux.o
            COMMAND ${LINUX_GCC} -std=c++20 -c -fPIC
                    ${CMAKE_CURRENT_SOURCE_DIR}/DBCClient/server.cpp
                    -o ${CMAKE_CURRENT_BINARY_DIR}/server_linux.o
            DEPENDS DBCClient/server.cpp
            COMMENT "Cross-compiling server.cpp for Linux"
        )
        # Create a separate library for the cross-compiled server
        add_library(server_linux STATIC ${CMAKE_CURRENT_BINARY_DIR}/server_linux.o)
        set_target_properties(server_linux PROPERTIES LINKER_LANGUAGE CXX)
        # Don't link to main Windows executable - create separate Linux binary
        add_custom_target(server_executable
            COMMAND ${LINUX_GCC} ${CMAKE_CURRENT_BINARY_DIR}/server_linux.o -o server_linux_binary
            DEPENDS server_linux
            COMMENT "Creating Linux server executable"
        )
    else()
        message(WARNING "Linux cross-compiler not found. Install mingw-w64 cross-compilation tools.")
    endif()
else()
    message(STATUS "Excluding server.cpp - not a Linux build")
endif()

# Main executable with platform-specific sources
qt_add_executable(appDBC_Parser ${COMMON_SOURCES})

# Create separate server executable for Linux builds
if(UNIX AND NOT APPLE)
    add_executable(dbc_server DBCClient/server.cpp)
    message(STATUS "Creating separate DBC server executable")
endif()

# Create QML resources for Qt6.2 compatibility
set(QML_SOURCES
    Main.qml
    AddMessageDialog.qml
    AddSignalDialog.qml
    SendMessageDialog.qml
    TcpClientTab.qml
    qmldir
    dbctrain.png
)

# Use qt_add_qml_module with Qt6.2 compatible settings
qt_add_qml_module(appDBC_Parser
    URI DBC_Parser
    VERSION 1.0
    QML_FILES ${QML_SOURCES}
    RESOURCE_PREFIX "/qt/qml"
)

# Platform-specific compile definitions
if(UNIX AND NOT APPLE)
    target_compile_definitions(appDBC_Parser PRIVATE HAS_SERVER_SUPPORT LINUX_BUILD)
    message(STATUS "Building with server support on Linux")
endif()

# Set target properties
set_target_properties(appDBC_Parser PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

# Link libraries - ADD Qt6::Network for TCP functionality
target_link_libraries(appDBC_Parser
    PRIVATE
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Network
)

# Fix for AGL framework issue on newer macOS
if(APPLE)
    set_target_properties(appDBC_Parser PROPERTIES
        LINK_FLAGS "-Wl,-U,_CGLChoosePixelFormat -Wl,-U,_CGLCreateContext -Wl,-U,_CGLSetCurrentContext -Wl,-U,_CGLDestroyContext"
    )
endif()

include(GNUInstallDirs)

# Install main GUI application
install(TARGETS appDBC_Parser
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# Install server executable (Linux only)
if(UNIX AND NOT APPLE)
    install(TARGETS dbc_server
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    )
endif()
