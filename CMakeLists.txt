cmake_minimum_required(VERSION 3.16)
project(DBC_Parser VERSION 0.1 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Don't set RPATH for packaging
set(CMAKE_SKIP_RPATH TRUE)
set(CMAKE_SKIP_INSTALL_RPATH TRUE)

# Add Network component for TCP functionality in Qtclient.cpp
find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Network)
qt_standard_project_setup(REQUIRES 6.5)

# Cross-compilation option for server.cpp
option(CROSS_COMPILE_SERVER "Cross-compile server.cpp for Linux from Windows" OFF)

# Define source files based on platform
set(COMMON_SOURCES
    main.cpp
    DbcParser.cpp
    DbcSender.cpp
)

# Only add Qtclient.cpp, not the entire DBCClient folder
list(APPEND COMMON_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/DBCClient/Qtclient.cpp)

# Note: DBCClient/server.cpp is intentionally excluded as it contains its own main()
# It's a separate server program and should be built independently if needed

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
        DbcSender.h
        DBCClient/Qtclient.h
    RESOURCES
        DBCClient/README
)

qt_add_resources(appDBC_Parser app_icons
    PREFIX "/"
    FILES
        deploy-assets/dbctrain.ico
        deploy-assets/dbctrain.png
)

if(WIN32)
    # Use an explicit path to ensure CMake can locate the resource file in all build contexts
    target_sources(appDBC_Parser PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/appicon.rc)
endif()

# Platform-specific compile definitions
if(UNIX AND NOT APPLE)
    # Don't define HAS_SERVER_SUPPORT since we're not building server
    target_compile_definitions(appDBC_Parser PRIVATE LINUX_BUILD)
    message(STATUS "Building without server support on Linux")
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
install(TARGETS appDBC_Parser
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# ============================================================================
# Deployment Targets
# ============================================================================

# Windows deployment using windeployqt
if(WIN32)
    # Find windeployqt in Qt installation
    get_target_property(QT_QMAKE_EXECUTABLE Qt6::qmake IMPORTED_LOCATION)
    get_filename_component(QT_BIN_DIR "${QT_QMAKE_EXECUTABLE}" DIRECTORY)
    find_program(WINDEPLOYQT_EXECUTABLE windeployqt HINTS "${QT_BIN_DIR}")
    
    if(WINDEPLOYQT_EXECUTABLE)
        message(STATUS "Found windeployqt: ${WINDEPLOYQT_EXECUTABLE}")
        
        # Create deployment target
        add_custom_target(deploy
            COMMAND ${CMAKE_COMMAND} -E remove_directory "${CMAKE_BINARY_DIR}/deploy"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_BINARY_DIR}/deploy"
            COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:appDBC_Parser> "${CMAKE_BINARY_DIR}/deploy/"
            COMMAND ${WINDEPLOYQT_EXECUTABLE}
                --release
                --qmldir "${CMAKE_SOURCE_DIR}"
                --no-compiler-runtime
                --no-translations
                "${CMAKE_BINARY_DIR}/deploy/$<TARGET_FILE_NAME:appDBC_Parser>"
            COMMAND ${CMAKE_COMMAND} -E echo "Windows deployment complete: ${CMAKE_BINARY_DIR}/deploy"
            DEPENDS appDBC_Parser
            COMMENT "Deploying Windows application with windeployqt"
            VERBATIM
        )
        
        # Create ZIP archive target
        add_custom_target(package
            COMMAND ${CMAKE_COMMAND} -E tar "cfv" "DBC_Parser_Windows.zip" --format=zip "${CMAKE_BINARY_DIR}/deploy"
            DEPENDS deploy
            COMMENT "Creating Windows deployment package"
            VERBATIM
        )
    else()
        message(WARNING "windeployqt not found. Deployment target will not be available.")
    endif()
endif()

# Linux deployment using linuxdeploy (requires linuxdeploy-x86_64.AppImage)
if(UNIX AND NOT APPLE)
    # Check if deployment script exists
    if(EXISTS "${CMAKE_SOURCE_DIR}/scripts/deploy-linux.sh")
        add_custom_target(deploy
            COMMAND bash "${CMAKE_SOURCE_DIR}/scripts/deploy-linux.sh"
            DEPENDS appDBC_Parser
            WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
            COMMENT "Deploying Linux application with linuxdeploy (creates AppImage)"
            VERBATIM
        )
        
        message(STATUS "Linux deployment target available: cmake --build . --target deploy")
    else()
    message(WARNING "scripts/deploy-linux.sh not found. Deployment target will not be available.")
    endif()
endif()

# macOS deployment using macdeployqt
if(APPLE)
    get_target_property(QT_QMAKE_EXECUTABLE Qt6::qmake IMPORTED_LOCATION)
    get_filename_component(QT_BIN_DIR "${QT_QMAKE_EXECUTABLE}" DIRECTORY)
    find_program(MACDEPLOYQT_EXECUTABLE macdeployqt HINTS "${QT_BIN_DIR}")
    
    if(MACDEPLOYQT_EXECUTABLE)
        message(STATUS "Found macdeployqt: ${MACDEPLOYQT_EXECUTABLE}")
        
        add_custom_target(deploy
            COMMAND ${MACDEPLOYQT_EXECUTABLE}
                $<TARGET_BUNDLE_DIR:appDBC_Parser>
                -qmldir="${CMAKE_SOURCE_DIR}"
                -always-overwrite
            DEPENDS appDBC_Parser
            COMMENT "Deploying macOS application with macdeployqt"
            VERBATIM
        )
        
        # Create DMG target
        add_custom_target(package
            COMMAND hdiutil create -volname "DBC Parser" -srcfolder $<TARGET_BUNDLE_DIR:appDBC_Parser> -ov -format UDZO "DBC_Parser.dmg"
            DEPENDS deploy
            COMMENT "Creating macOS DMG package"
            VERBATIM
        )
    else()
        message(WARNING "macdeployqt not found. Deployment target will not be available.")
    endif()
endif()
