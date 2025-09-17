import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import TcpClient 1.0

Rectangle {
    id: root
    color: "white"

    // Expose the TCP client to parent components
    property alias tcpClient: tcpClient

    TcpClientBackend {
        id: tcpClient

        onConnectionStatusChanged: {
            console.log("TCP Connection status changed:", connected)
            statusIndicator.updateStatus()
        }

        onResponseReceived: {
            // Add response to the message history
            var timestamp = new Date().toLocaleTimeString()
            messageHistory.append({
                "timestamp": timestamp,
                "type": "response",
                "content": lastResponse
            })
            messageListView.positionViewAtEnd()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // Header
        Rectangle {
            Layout.fillWidth: true
            height: 60
            color: "#FAFAFA"
            radius: 8
            border.color: "#E0E0E0"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 15

                Rectangle {
                    id: statusIndicator
                    width: 12
                    height: 12
                    radius: 6
                    color: tcpClient.connected ? "#4CAF50" : "#F44336"

                    function updateStatus() {
                        color = tcpClient.connected ? "#4CAF50" : "#F44336"
                    }

                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }
                }

                Text {
                    text: "TCP Client"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    color: "#2E7D32"
                }

                Text {
                    text: tcpClient.connected ? "Connected" : "Disconnected"
                    font.pixelSize: 14
                    color: tcpClient.connected ? "#4CAF50" : "#757575"
                }

                Item { Layout.fillWidth: true }
            }
        }

        // Connection controls
        GroupBox {
            title: "Server Connection"
            Layout.fillWidth: true

            background: Rectangle {
                color: "white"
                border.color: "#E0E0E0"
                border.width: 1
                radius: 4
            }

            label: Label {
                text: parent.title
                font.pixelSize: 14
                font.weight: Font.Medium
                color: "#424242"
                leftPadding: 8
                rightPadding: 8
                background: Rectangle {
                    color: "white"
                }
            }

            GridLayout {
                anchors.fill: parent
                anchors.margins: 15
                columns: 4
                rowSpacing: 15
                columnSpacing: 15

                Label {
                    text: "Server IP:"
                    font.pixelSize: 13
                    color: "#616161"
                }

                TextField {
                    id: ipField
                    Layout.preferredWidth: 150
                    text: "127.0.0.1"
                    enabled: !tcpClient.connected
                    placeholderText: "e.g., 192.168.1.100"
                    selectByMouse: true

                    background: Rectangle {
                        color: parent.enabled ? "white" : "#F5F5F5"
                        border.color: parent.activeFocus ? "#4CAF50" : "#E0E0E0"
                        border.width: 1
                        radius: 4
                    }
                }

                Label {
                    text: "Port:"
                    font.pixelSize: 13
                    color: "#616161"
                }

                TextField {
                    id: portField
                    Layout.preferredWidth: 100
                    text: "8080"
                    enabled: !tcpClient.connected
                    validator: IntValidator { bottom: 1; top: 65535 }
                    placeholderText: "8080"
                    selectByMouse: true

                    background: Rectangle {
                        color: parent.enabled ? "white" : "#F5F5F5"
                        border.color: parent.activeFocus ? "#4CAF50" : "#E0E0E0"
                        border.width: 1
                        radius: 4
                    }
                }

                Button {
                    id: connectButton
                    Layout.columnSpan: 4
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    text: tcpClient.connected ? "Disconnect" : "Connect"

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }

                    background: Rectangle {
                        color: tcpClient.connected ?
                               (parent.pressed ? "#D32F2F" : (parent.hovered ? "#E53935" : "#F44336")) :
                               (parent.pressed ? "#2E7D32" : (parent.hovered ? "#388E3C" : "#4CAF50"))
                        radius: 4

                        Behavior on color {
                            ColorAnimation { duration: 100 }
                        }
                    }

                    onClicked: {
                        if (tcpClient.connected) {
                            tcpClient.disconnect()
                        } else {
                            var success = tcpClient.connectToServer(ipField.text, parseInt(portField.text))
                            if (success) {
                                messageHistory.append({
                                    "timestamp": new Date().toLocaleTimeString(),
                                    "type": "system",
                                    "content": "Connected to " + ipField.text + ":" + portField.text
                                })
                            } else {
                                messageHistory.append({
                                    "timestamp": new Date().toLocaleTimeString(),
                                    "type": "error",
                                    "content": "Failed to connect to " + ipField.text + ":" + portField.text
                                })
                            }
                            messageListView.positionViewAtEnd()
                        }
                    }
                }
            }
        }

        // Message history
        GroupBox {
            title: "Message History"
            Layout.fillWidth: true
            Layout.fillHeight: true

            background: Rectangle {
                color: "white"
                border.color: "#E0E0E0"
                border.width: 1
                radius: 4
            }

            label: Label {
                text: parent.title
                font.pixelSize: 14
                font.weight: Font.Medium
                color: "#424242"
                leftPadding: 8
                rightPadding: 8
                background: Rectangle {
                    color: "white"
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        id: messageListView
                        model: ListModel {
                            id: messageHistory
                        }

                        delegate: Rectangle {
                            width: parent.width
                            height: messageContent.height + 20
                            color: index % 2 === 0 ? "#FAFAFA" : "white"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                Text {
                                    text: model.timestamp
                                    font.pixelSize: 11
                                    color: "#757575"
                                    Layout.preferredWidth: 70
                                }

                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: model.type === "sent" ? "#2196F3" :
                                           model.type === "response" ? "#4CAF50" :
                                           model.type === "error" ? "#F44336" : "#FF9800"
                                }

                                Text {
                                    id: messageContent
                                    Layout.fillWidth: true
                                    text: model.content
                                    font.pixelSize: 13
                                    color: model.type === "error" ? "#D32F2F" : "#424242"
                                    wrapMode: Text.Wrap
                                    selectByMouse: true
                                }
                            }
                        }
                    }
                }

                Button {
                    Layout.alignment: Qt.AlignRight
                    text: "Clear History"
                    enabled: messageHistory.count > 0

                    background: Rectangle {
                        color: parent.pressed ? "#E0E0E0" :
                               (parent.hovered ? "#F5F5F5" : "transparent")
                        border.color: "#BDBDBD"
                        border.width: 1
                        radius: 4
                    }

                    onClicked: messageHistory.clear()
                }
            }
        }

        // Send message section
        GroupBox {
            title: "Send Message"
            Layout.fillWidth: true
            enabled: tcpClient.connected

            background: Rectangle {
                color: parent.enabled ? "white" : "#F9F9F9"
                border.color: "#E0E0E0"
                border.width: 1
                radius: 4
            }

            label: Label {
                text: parent.title
                font.pixelSize: 14
                font.weight: Font.Medium
                color: parent.parent.enabled ? "#424242" : "#9E9E9E"
                leftPadding: 8
                rightPadding: 8
                background: Rectangle {
                    color: parent.parent.enabled ? "white" : "#F9F9F9"
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                TextField {
                    id: messageField
                    Layout.fillWidth: true
                    placeholderText: "Enter message to send..."
                    enabled: tcpClient.connected
                    selectByMouse: true

                    background: Rectangle {
                        color: parent.enabled ? "white" : "#F5F5F5"
                        border.color: parent.activeFocus ? "#4CAF50" : "#E0E0E0"
                        border.width: 1
                        radius: 4
                    }

                    onAccepted: sendButton.clicked()
                }

                Button {
                    id: sendButton
                    text: "Send"
                    enabled: tcpClient.connected && messageField.text.trim().length > 0
                    Layout.preferredHeight: messageField.height

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    background: Rectangle {
                        color: parent.enabled ?
                               (parent.pressed ? "#2E7D32" : (parent.hovered ? "#388E3C" : "#4CAF50")) :
                               "#CCCCCC"
                        radius: 4

                        Behavior on color {
                            ColorAnimation { duration: 100 }
                        }
                    }

                    onClicked: {
                        if (messageField.text.trim() !== "") {
                            var message = messageField.text.trim()

                            // Add sent message to history
                            messageHistory.append({
                                "timestamp": new Date().toLocaleTimeString(),
                                "type": "sent",
                                "content": message
                            })

                            // Send the message
                            var response = tcpClient.sendMessage(message)

                            // If there was an error (not handled by onResponseReceived), add it to history
                            if (response && !tcpClient.connected) {
                                messageHistory.append({
                                    "timestamp": new Date().toLocaleTimeString(),
                                    "type": "error",
                                    "content": response
                                })
                            }

                            messageField.text = ""
                            messageListView.positionViewAtEnd()
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        var settings = tcpClient.getSavedSettings()
        if (settings.length >= 2) {
            ipField.text = settings[0]
            portField.text = settings[1]
        }
    }
}
