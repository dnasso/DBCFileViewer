import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

Dialog {
    id: addMessageDialog
    title: "Add New CAN Message"
    modal: true
    anchors.centerIn: parent
    width: 500
    height: 400

    background: Rectangle {
        color: "white"
        radius: 8
        border.color: "#E0E0E0"
        border.width: 1
    }

    header: Rectangle {
        height: 60
        color: "#4CAF50"
        radius: 8

        Text {
            anchors.centerIn: parent
            text: addMessageDialog.title
            font.pixelSize: 18
            font.weight: Font.Bold
            color: "white"
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: "#388E3C"
        }
    }

    contentItem: Item {
        anchors.fill: parent

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 50
            spacing: 20

            // Spacer from top
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 15
            }

            // Message Name
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

            Text {
                text: "Message Name:"
                font.pixelSize: 15
                font.weight: Font.Medium
                color: "#424242"
                Layout.alignment: Qt.AlignLeft
            }

            TextField {
                id: nameField
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                font.pixelSize: 14
                selectByMouse: true
                padding: 12

                background: Rectangle {
                    color: "white"
                    radius: 6
                    border.color: parent.activeFocus ? "#4CAF50" : "#BDBDBD"
                    border.width: parent.activeFocus ? 2 : 1
                }
            }
        }

            // Message ID
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

            Text {
                text: "Message ID (hex):"
                font.pixelSize: 15
                font.weight: Font.Medium
                color: "#424242"
                Layout.alignment: Qt.AlignLeft
            }

            TextField {
                id: idField
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                font.pixelSize: 14
                selectByMouse: true
                padding: 12
                validator: RegularExpressionValidator { regularExpression: /^(0x)?[0-9A-Fa-f]+$/ }

                background: Rectangle {
                    color: "white"
                    radius: 6
                    border.color: parent.activeFocus ? "#4CAF50" : "#BDBDBD"
                    border.width: parent.activeFocus ? 2 : 1
                }
            }
        }

            // Message Length
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

            Text {
                text: "Length (bytes):"
                font.pixelSize: 15
                font.weight: Font.Medium
                color: "#424242"
                Layout.alignment: Qt.AlignLeft
            }

            SpinBox {
                id: lengthSpinBox
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                from: 1
                to: 64
                value: 8
                editable: true

                contentItem: TextField {
                    text: parent.value
                    font.pixelSize: 14
                    color: "#424242"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    selectByMouse: true
                    validator: IntValidator { bottom: 1; top: 64 }
                    padding: 12

                    background: Rectangle {
                        color: "transparent"
                        border.width: 0
                    }
                }

                background: Rectangle {
                    color: "white"
                    radius: 6
                    border.color: parent.activeFocus ? "#4CAF50" : "#BDBDBD"
                    border.width: parent.activeFocus ? 2 : 1
                }
            }
        }

            // Error Label
            Text {
                id: errorLabel
                color: "#D32F2F"
                visible: text !== ""
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            // Spacer from bottom
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 15
            }
        }
    }

    footer: DialogButtonBox {
        padding: 15
        background: Rectangle {
            color: "#FAFAFA"
            radius: 8
        }

        Button {
            text: "Cancel"
            DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
            flat: true

            contentItem: Text {
                text: parent.text
                color: "#757575"
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            background: Rectangle {
                color: parent.pressed ? "#E0E0E0" : "transparent"
                radius: 4
            }
        }

        Button {
            text: "Add Message"
            DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole

            contentItem: Text {
                text: parent.text
                color: "white"
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            background: Rectangle {
                color: parent.pressed ? "#388E3C" : "#4CAF50"
                radius: 4
            }
        }
    }

    onAccepted: {
        errorLabel.text = ""

        // Validate input
        if (nameField.text.trim() === "") {
            errorLabel.text = "Please enter a message name"
            open()
            return
        }

        if (idField.text.trim() === "") {
            errorLabel.text = "Please enter a message ID"
            open()
            return
        }

        // Parse ID (handle both hex and decimal)
        var idValue = parseInt(idField.text, idField.text.startsWith("0x") ? 16 : 16)

        if (isNaN(idValue)) {
            errorLabel.text = "Invalid message ID format"
            open()
            return
        }

        // Use enhanced validation
        var validationError = dbcParser.validateMessageData(nameField.text.trim(), idValue, lengthSpinBox.value)
        if (validationError !== "") {
            errorLabel.text = validationError
            open()
            return
        }

        // Add the message
        if (!dbcParser.addMessage(nameField.text.trim(), idValue, lengthSpinBox.value)) {
            errorLabel.text = "Failed to add message due to an unexpected error"
            open()
            return
        }

        // Clear fields for next use
        nameField.text = ""
        idField.text = ""
        lengthSpinBox.value = 8
    }

    onRejected: {
        // Clear fields
        nameField.text = ""
        idField.text = ""
        lengthSpinBox.value = 8
        errorLabel.text = ""
    }

    onOpened: {
        nameField.text = ""
        idField.text = ""
        lengthSpinBox.value = 8
        errorLabel.text = ""
        nameField.forceActiveFocus()
    }
}
