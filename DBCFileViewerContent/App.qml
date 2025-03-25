// Copyright (C) 2021 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR GPL-3.0-only

import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import DBCFileViewer

Window {
    width: mainScreen.width
    height: mainScreen.height

    visible: true
    title: "DBCFileViewer"

    Screen01 {
        id: mainScreen
    }

    FileDialog {
        id: fileDialog
        title: "Select a file"
        currentFolder: StandardPaths.standardLocations(StandardPaths.DocumentsLocation)[0]
        onAccepted: {
            filePath.text = "Selected file: " + fileDialog.fileUrl
        }
        onRejected: {
            console.log("File selection canceled")
        }
    }

    Connections {
        target: fileDialog
        function onAccepted() { console.log("clicked") }
    }

}

