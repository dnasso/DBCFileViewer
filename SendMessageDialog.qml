import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Dialog {
    id: sendMessageDialog
    title: "Send CAN Message"
    modal: true
    anchors.centerIn: parent
    width: 750
    height: 700

    property string messageName: ""
    property string messageId: ""
    property string hexData: ""
    property int transmissionRate: 100 // Default rate in milliseconds
    property bool isSending: false

    Material.theme: Material.Light
    Material.accent: Material.Green

    background: Rectangle {
        color: "white"
        radius: 8
        border.color: "#E0E0E0"
        border.width: 1
    }

    header: Rectangle {
        height: 70
        color: "#4CAF50"
        radius: 8

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 30
            anchors.rightMargin: 30

            Column {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: "Send CAN Message"
                    font.pixelSize: 22
                    font.weight: Font.Bold
                    color: "white"
                }

                Text {
                    text: "Configure message transmission settings"
                    font.pixelSize: 14
                    color: "white"
                    opacity: 0.9
                }
            }

            // Status indicator
            Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: 12
                color: sendMessageDialog.isSending ? "#FFD54F" : "white"
                opacity: 0.9

                Rectangle {
                    anchors.centerIn: parent
                    width: 12
                    height: 12
                    radius: 6
                    color: sendMessageDialog.isSending ? "#FF9800" : "#4CAF50"
                }
            }
        }
    }

    onOpened: {
        // Update message information when dialog opens
        if (messageName) {
            messageId = "0x" + dbcParser.getMessageId(messageName).toString(16).toUpperCase()
            hexData = dbcParser.getMessageHexData(messageName)
        }
    }

    contentItem: ScrollView {
        clip: true
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: 25
            anchors.margins: 25

            // Message Information Section
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                Layout.leftMargin: 25
                Layout.rightMargin: 25
                Layout.topMargin: 20
                color: "#F8F9FA"
                radius: 8
                border.color: "#E8F5E9"
                border.width: 2

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 15

                    Text {
                        text: "Message Information"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: "#2E7D32"
                        Layout.alignment: Qt.AlignLeft
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 12
                        columnSpacing: 20

                        Text {
                            text: "Message Name:"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: "#424242"
                            Layout.preferredWidth: 110
                            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                        }

                        Text {
                            text: sendMessageDialog.messageName
                            font.pixelSize: 13
                            color: "#616161"
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                            elide: Text.ElideRight
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            text: "CAN ID:"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: "#424242"
                            Layout.preferredWidth: 110
                            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                        }

                        Text {
                            text: sendMessageDialog.messageId
                            font.pixelSize: 13
                            font.family: "Monospace"
                            color: "#616161"
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                        }

                        Text {
                            text: "Hex Data:"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: "#424242"
                            Layout.preferredWidth: 110
                            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 35
                            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                            color: "white"
                            radius: 4
                            border.color: "#E0E0E0"
                            border.width: 1

                            Text {
                                anchors.fill: parent
                                anchors.margins: 10
                                text: sendMessageDialog.hexData
                                font.family: "Monospace"
                                font.pixelSize: 12
                                color: "#424242"
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            // Transmission Settings Section
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 160
                Layout.leftMargin: 25
                Layout.rightMargin: 25
                color: "#F8F9FA"
                radius: 8
                border.color: "#E8F5E9"
                border.width: 2

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 15

                    Text {
                        text: "Transmission Settings"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: "#2E7D32"
                        Layout.alignment: Qt.AlignLeft
                    }

                    // Rate input row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 15
                        Layout.alignment: Qt.AlignLeft

                        Text {
                            text: "Rate (ms):"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: "#424242"
                            Layout.preferredWidth: 80
                            Layout.alignment: Qt.AlignVCenter
                        }

                        SpinBox {
                            id: rateSpinBox
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 35
                            from: 1
                            to: 10000
                            value: sendMessageDialog.transmissionRate
                            editable: true
                            font.pixelSize: 13

                            onValueChanged: {
                                sendMessageDialog.transmissionRate = value
                            }
                        }

                        Text {
                            text: "(" + (1000.0 / sendMessageDialog.transmissionRate).toFixed(1) + " Hz)"
                            font.pixelSize: 12
                            color: "#757575"
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { Layout.fillWidth: true } // Spacer
                    }

                    // Preset buttons
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "Quick Presets:"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: "#424242"
                            Layout.alignment: Qt.AlignLeft
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Layout.alignment: Qt.AlignLeft

                            Button {
                                text: "1ms (1kHz)"
                                Layout.preferredWidth: 85
                                Layout.preferredHeight: 32
                                enabled: !sendMessageDialog.isSending

                                background: Rectangle {
                                    color: parent.pressed ? "#C8E6C9" : (parent.hovered ? "#E8F5E9" : "white")
                                    border.color: "#4CAF50"
                                    border.width: 1
                                    radius: 4
                                }

                                contentItem: Text {
                                    text: parent.text
                                    color: parent.enabled ? "#4CAF50" : "#CCCCCC"
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: rateSpinBox.value = 1
                            }

                            Button {
                                text: "10ms (100Hz)"
                                Layout.preferredWidth: 85
                                Layout.preferredHeight: 32
                                enabled: !sendMessageDialog.isSending

                                background: Rectangle {
                                    color: parent.pressed ? "#C8E6C9" : (parent.hovered ? "#E8F5E9" : "white")
                                    border.color: "#4CAF50"
                                    border.width: 1
                                    radius: 4
                                }

                                contentItem: Text {
                                    text: parent.text
                                    color: parent.enabled ? "#4CAF50" : "#CCCCCC"
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: rateSpinBox.value = 10
                            }

                            Button {
                                text: "100ms (10Hz)"
                                Layout.preferredWidth: 85
                                Layout.preferredHeight: 32
                                enabled: !sendMessageDialog.isSending

                                background: Rectangle {
                                    color: parent.pressed ? "#C8E6C9" : (parent.hovered ? "#E8F5E9" : "white")
                                    border.color: "#4CAF50"
                                    border.width: 1
                                    radius: 4
                                }

                                contentItem: Text {
                                    text: parent.text
                                    color: parent.enabled ? "#4CAF50" : "#CCCCCC"
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: rateSpinBox.value = 100
                            }

                            Button {
                                text: "1000ms (1Hz)"
                                Layout.preferredWidth: 85
                                Layout.preferredHeight: 32
                                enabled: !sendMessageDialog.isSending

                                background: Rectangle {
                                    color: parent.pressed ? "#C8E6C9" : (parent.hovered ? "#E8F5E9" : "white")
                                    border.color: "#4CAF50"
                                    border.width: 1
                                    radius: 4
                                }

                                contentItem: Text {
                                    text: parent.text
                                    color: parent.enabled ? "#4CAF50" : "#CCCCCC"
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: rateSpinBox.value = 1000
                            }

                            Item { Layout.fillWidth: true } // Spacer
                        }
                    }
                }
            }

            // Message Preview Section
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                Layout.leftMargin: 25
                Layout.rightMargin: 25
                Layout.bottomMargin: 10
                color: "#FFF3E0"
                radius: 8
                border.color: "#FFB74D"
                border.width: 2

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    Text {
                        text: "Message Preview"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: "#E65100"
                        Layout.alignment: Qt.AlignLeft
                    }

                    Text {
                        text: "Message to be sent:"
                        font.pixelSize: 12
                        color: "#BF360C"
                        Layout.alignment: Qt.AlignLeft
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        color: "white"
                        radius: 4
                        border.color: "#FFB74D"
                        border.width: 1

                        Text {
                            anchors.fill: parent
                            anchors.margins: 12
                            text: sendMessageDialog.messageId + " | " + sendMessageDialog.hexData + " | " + sendMessageDialog.transmissionRate + "ms"
                            font.family: "Monospace"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: "#E65100"
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        text: "Format: CAN_ID | HEX_DATA | RATE_MS"
                        font.pixelSize: 10
                        color: "#8D6E63"
                        font.italic: true
                        Layout.alignment: Qt.AlignLeft
                    }
                }
            }
        }
    }

    footer: Rectangle {
        height: 70
        color: "#FAFAFA"

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: "#E0E0E0"
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 25
            anchors.rightMargin: 25
            anchors.topMargin: 15
            anchors.bottomMargin: 15
            spacing: 15

            // Status text (left side)
            Text {
                text: sendMessageDialog.isSending ? "Transmission in progress..." : "Ready to transmit message"
                font.pixelSize: 13
                color: sendMessageDialog.isSending ? "#FF9800" : "#757575"
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                SequentialAnimation on opacity {
                    running: sendMessageDialog.isSending
                    loops: Animation.Infinite

                    PropertyAnimation { to: 0.4; duration: 800 }
                    PropertyAnimation { to: 1.0; duration: 800 }
                }
            }

            // Buttons (right side)
            Button {
                id: cancelButton
                text: sendMessageDialog.isSending ? "Stop" : "Cancel"
                Layout.preferredWidth: 100
                Layout.preferredHeight: 36
                Layout.alignment: Qt.AlignVCenter

                background: Rectangle {
                    color: parent.pressed ? "#FFCDD2" : (parent.hovered ? "#FFEBEE" : "white")
                    border.color: sendMessageDialog.isSending ? "#F44336" : "#BDBDBD"
                    border.width: 1
                    radius: 4
                }

                contentItem: Text {
                    text: parent.text
                    color: sendMessageDialog.isSending ? "#F44336" : "#616161"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    if (sendMessageDialog.isSending) {
                        // TODO: Stop transmission
                        sendMessageDialog.isSending = false
                    }
                    sendMessageDialog.close()
                }
            }

            Button {
                id: sendButton
                text: sendMessageDialog.isSending ? "Sending..." : "Send Message"
                Layout.preferredWidth: 120
                Layout.preferredHeight: 36
                Layout.alignment: Qt.AlignVCenter
                enabled: !sendMessageDialog.isSending

                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: parent.enabled ?
                        (parent.pressed ? "#388E3C" : (parent.hovered ? "#43A047" : "#4CAF50")) :
                        "#CCCCCC"
                    radius: 4

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }

                onClicked: {
                    // Call the backend method to send the message
                    if (dbcParser.sendCanMessage(sendMessageDialog.messageName, sendMessageDialog.transmissionRate)) {
                        sendMessageDialog.isSending = true

                        // For demo purposes, automatically stop after 5 seconds
                        // Remove this timer when you implement real server communication
                        Qt.callLater(function() {
                            demoTimer.start()
                        })

                        console.log("Started sending message:", sendMessageDialog.messageName, "at rate:", sendMessageDialog.transmissionRate, "ms")
                    } else {
                        console.log("Failed to send message:", sendMessageDialog.messageName)
                    }
                }
            }
        }
    }

    // Demo timer to simulate stopping transmission (remove this when implementing real server)
    Timer {
        id: demoTimer
        interval: 5000 // 5 seconds
        repeat: false
        onTriggered: {
            sendMessageDialog.isSending = false
        }
    }
}
