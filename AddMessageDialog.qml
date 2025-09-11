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
    height: 350

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

    contentItem: ColumnLayout {
        spacing: 15
        anchors.margins: 20

        // Message Name
        ColumnLayout {
            spacing: 5

            Text {
                text: "Message Name:"
                font.pixelSize: 14
                font.weight: Font.Medium
                color: "#424242"
            }

            TextField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: "Enter message name"
                font.pixelSize: 14
                selectByMouse: true

                background: Rectangle {
                    color: "white"
                    radius: 4
                    border.color: parent.activeFocus ? "#4CAF50" : "#BDBDBD"
                    border.width: 1
                }
            }
        }

        // Message ID
        ColumnLayout {
            spacing: 5

            Text {
                text: "Message ID (hex):"
                font.pixelSize: 14
                font.weight: Font.Medium
                color: "#424242"
            }

            TextField {
                id: idField
                Layout.fillWidth: true
                placeholderText: "e.g., 0x123 or 123"
                font.pixelSize: 14
                selectByMouse: true
                validator: RegularExpressionValidator { regularExpression: /^(0x)?[0-9A-Fa-f]+$/ }

                background: Rectangle {
                    color: "white"
                    radius: 4
                    border.color: parent.activeFocus ? "#4CAF50" : "#BDBDBD"
                    border.width: 1
                }
            }
        }

        // Message Length
        ColumnLayout {
            spacing: 5

            Text {
                text: "Length (bytes):"
                font.pixelSize: 14
                font.weight: Font.Medium
                color: "#424242"
            }

            SpinBox {
                id: lengthSpinBox
                Layout.fillWidth: true
                from: 1
                to: 64
                value: 8
                editable: true

                contentItem: TextField {
                    text: parent.value
                    font: parent.font
                    color: "#424242"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    selectByMouse: true
                    validator: IntValidator { bottom: 1; top: 64 }
                }

                background: Rectangle {
                    color: "white"
                    radius: 4
                    border.color: parent.activeFocus ? "#4CAF50" : "#BDBDBD"
                    border.width: 1
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
            font.pixelSize: 12
        }

        // Spacer
        Item {
            Layout.fillHeight: true
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
