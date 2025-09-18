cmake_minimum_required(VERSION 3.16)
project(DBC_Parser VERSION 0.1 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Add Network component for TCP functionality in Qtclient.cpp
find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Network)
qt_standard_project_setup(REQUIRES 6.5)

# Cross-compilation option for server.cpp
option(CROSS_COMPILE_SERVER "Cross-compile server.cpp for Linux from Windows" OFF)

# Define source files based on platform
set(COMMON_SOURCES
    main.cpp
    DbcParser.cpp
    ./DBCClient/Qtclient.cpp
)

# Handle server.cpp compilation
if(UNIX AND NOT APPLE)
    list(APPEND COMMON_SOURCES DBCClient/server.cpp)
    message(STATUS "Adding server.cpp for Linux build")
elseif(WIN32 AND DEFINED ENV{WSL_DISTRO_NAME})
    # We're in WSL - treat as Linux
    list(APPEND COMMON_SOURCES DBCClient/server.cpp)
    message(STATUS "Adding server.cpp for WSL build")
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

# QML module
qt_add_qml_module(appDBC_Parser
    URI DBC_Parser
    VERSION 1.0
    QML_FILES
        Main.qml
        AddMessageDialog.qml
        AddSignalDialog.qml
        SendMessageDialog.qml
        TcpClientTab.qml
    SOURCES
        DbcParser.h
        DbcParser.cpp
        DBCClient/Qtclient.h
    RESOURCES
        DBCClient/Makefile
        DBCClient/README
        DBCClient/server.conf
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

# Install
include(GNUInstallDirs)
install(TARGETS appDBC_Parser
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
