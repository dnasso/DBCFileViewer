// Copyright (C) 2021 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR GPL-3.0-only

import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import DBCFileViewer
//import "DbcParser.cpp"
//import QtQuick.Window


Window {
    width: 1046
    height: 788

    id: rootWindow
    // Set initial size based on the primary screen's available geometry
    // (availableGeometry excludes things like taskbars)
    //width: Screen.primaryScreen.availableWidth * 0.8 // 80% of available width
    //height: Screen.primaryScreen.availableHeight * 0.8 // 80% of available height

    visible: true
    title: "DBCFileViewer"

    Screen01 {
        id: mainScreen
        anchors.fill: parent
    }

    FileDialog {
        id: fileDialog
        title: "Select a file"
        selectedNameFilter.index: 1
        nameFilters: ["DBC files (*.dbc)"]
        currentFolder: StandardPaths.standardLocations(StandardPaths.DownloadLocation)[0]
        onAccepted: {
            filePath.text = "Selected file: " + fileDialog.fileUrl
        }
        onRejected: {
            console.log("File selection canceled")
        }
    }

    Connections {
        target: fileDialog
        function onAccepted() {
            //backend.parseFile(fileDialog.selectedFile)
            console.log("clicked")
        }
    }

}

