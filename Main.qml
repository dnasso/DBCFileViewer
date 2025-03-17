import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs

ApplicationWindow {
    visible: true
    width: 600
    height: 400
    title: "DBC Parser"

    FileDialog {
        id: fileDialog
        title: "Select a DBC File"
        nameFilters: ["DBC Files (*.dbc)"]
        onAccepted: dbcParser.loadDbcFile(fileDialog.fileUrl)
    }

    Column {
        anchors.fill: parent
        spacing: 10

        Button {
            text: "Load DBC File"
            onClicked: fileDialog.open()
        }

        ListView {
            id: messageList
            width: parent.width
            height: 150
            model: messageModel
            delegate: Item {
                width: parent.width
                height: 40

                Button {
                    text: modelData
                    onClicked: dbcParser.selectMessage(modelData)
                }
            }
        }

        CheckBox {
            id: showAllSignals
            text: "Show all signals"
            onCheckedChanged: dbcParser.setShowAllSignals(checked)
        }

        Column {
            id: signalInputs
            width: parent.width
        }

        Row {
            spacing: 10

            Text { text: "Endian:" }
            ButtonGroup { id: endianGroup }
            RadioButton {
                text: "Little"
                checked: true
                ButtonGroup.group: endianGroup
                onClicked: dbcParser.setEndian("little")
            }
            RadioButton {
                text: "Big"
                ButtonGroup.group: endianGroup
                onClicked: dbcParser.setEndian("big")
            }
        }

        TextField {
            id: outputField
            width: parent.width
            readOnly: true
        }

        Button {
            text: "Copy"
            onClicked: {
                outputField.selectAll()
                outputField.copy()
            }
        }
    }
}
