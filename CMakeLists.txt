cmake_minimum_required(VERSION 3.16)

project(DBC_Parser VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# macOS specific configuration to ensure proper SDK and headers are found
if(APPLE)
    execute_process(COMMAND xcrun --show-sdk-path OUTPUT_VARIABLE MACOS_SDK_PATH OUTPUT_STRIP_TRAILING_WHITESPACE)
    set(CMAKE_OSX_SYSROOT ${MACOS_SDK_PATH})
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -isysroot ${MACOS_SDK_PATH}")
endif()

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Network)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(appDBC_Parser
    main.cpp
    DbcParser.cpp
    DbcSender.cpp
)

qt_add_qml_module(appDBC_Parser
    URI DBC_Parser
    VERSION 1.0
    QML_FILES
        Main.qml
        AddMessageDialog.qml
        AddSignalDialog.qml
        SendMessageDialog.qml
        BitEditor.qml
    SOURCES 
        DbcParser.h
        DbcParser.cpp
        DbcSender.h
        DbcSender.cpp
    RESOURCES
        client.conf
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appDBC_Parser PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appDBC_Parser
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appDBC_Parser
    PRIVATE Qt6::Quick Qt6::QuickControls2 Qt6::Network
)

include(GNUInstallDirs)
install(TARGETS appDBC_Parser
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
