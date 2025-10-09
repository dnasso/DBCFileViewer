QT       += core gui quick quickcontrols2 network

CONFIG += c++17

TARGET = DBC_Parser
TEMPLATE = app

SOURCES += \
    main.cpp \
    DbcParser.cpp \
    DbcSender.cpp

HEADERS += \
    DbcParser.h \
    DbcSender.h

QML_FILES += \
    Main.qml \
    AddMessageDialog.qml \
    AddSignalDialog.qml \
    SendMessageDialog.qml \
    BitEditor.qml

RESOURCES += client.conf

# Linux specific settings
unix:!mac {
    QMAKE_CXXFLAGS += -fPIC
}

# Resource file (if needed)
OTHER_FILES += \
    $$QML_FILES \
    client.conf
