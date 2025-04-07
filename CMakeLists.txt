cmake_minimum_required(VERSION 3.16)

project(DBC_Parser VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Make sure this path is correct and points to Qt 6.8.3's MinGW kit (or another kit)
set(CMAKE_PREFIX_PATH "D:/Qt/6.8.3/mingw_64")

# Use only one find_package with all required components
find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(appDBC_Parser
    main.cpp
    DbcParser.cpp
)

qt_add_qml_module(appDBC_Parser
    URI DBC_Parser
    VERSION 1.0
    QML_FILES
        Main.qml
    SOURCES
        DbcParser.h
        DbcParser.cpp
)

set_target_properties(appDBC_Parser PROPERTIES
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
)

target_link_libraries(appDBC_Parser
    PRIVATE
        Qt6::Quick
        Qt6::QuickControls2
)

include(GNUInstallDirs)
install(TARGETS appDBC_Parser
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
