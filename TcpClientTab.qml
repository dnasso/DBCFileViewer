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
            
            // Notify the parent application about connection status change
            // The DbcParser should automatically sync because it was set up with setTcpClient
            messageHistory.append({
                "timestamp": new Date().toLocaleTimeString(),
                "type": "system",
                "content": connected ? "Connected to server" : "Disconnected from server"
            })
            messageListView.positionViewAtEnd()
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
        anchors.margins: 25
        anchors.bottomMargin: 50
        spacing: 25

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
                    text: "Client"
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
            height: 180

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
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 25
                anchors.bottomMargin: 90
                columns: 4
                rowSpacing: 20
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
                            // Also disconnect the DbcParser if available
                            if (typeof dbcParser !== 'undefined' && dbcParser !== null) {
                                dbcParser.disconnectFromServer()
                            }
                        } else {
                            // Validate inputs before attempting connection
                            if (ipField.text.trim() === "") {
                                if (typeof parent.parent.parent.parent.parent.showError !== 'undefined') {
                                    parent.parent.parent.parent.parent.showError("Please enter a valid IP address")
                                }
                                messageHistory.append({
                                    "timestamp": new Date().toLocaleTimeString(),
                                    "type": "error",
                                    "content": "Connection failed: IP address is required"
                                })
                                messageListView.positionViewAtEnd()
                                return
                            }
                            
                            if (portField.text.trim() === "" || isNaN(parseInt(portField.text)) || parseInt(portField.text) <= 0 || parseInt(portField.text) > 65535) {
                                if (typeof parent.parent.parent.parent.parent.showError !== 'undefined') {
                                    parent.parent.parent.parent.parent.showError("Please enter a valid port number (1-65535)")
                                }
                                messageHistory.append({
                                    "timestamp": new Date().toLocaleTimeString(),
                                    "type": "error",
                                    "content": "Connection failed: Invalid port number"
                                })
                                messageListView.positionViewAtEnd()
                                return
                            }
                            
                            var success = tcpClient.connectToServer(ipField.text, parseInt(portField.text))
                            if (success) {
                                messageHistory.append({
                                    "timestamp": new Date().toLocaleTimeString(),
                                    "type": "system",
                                    "content": "Connected to " + ipField.text + ":" + portField.text
                                })
                                
                                // Note: DbcParser will use the existing TCP connection
                                if (typeof parent.parent.parent.parent.parent.showSuccess !== 'undefined') {
                                    parent.parent.parent.parent.parent.showSuccess("Connected to CAN server successfully!")
                                }
                            } else {
                                messageHistory.append({
                                    "timestamp": new Date().toLocaleTimeString(),
                                    "type": "error",
                                    "content": "Failed to connect to " + ipField.text + ":" + portField.text
                                })
                                if (typeof parent.parent.parent.parent.parent.showError !== 'undefined') {
                                    parent.parent.parent.parent.parent.showError("Connection failed: Unable to connect to " + ipField.text + ":" + portField.text + ". Please check if the server is running and the IP/port are correct.")
                                }
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
                anchors.margins: 25
                anchors.topMargin: 30
                anchors.bottomMargin: 25
                spacing: 15

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 100
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    ListView {
                        id: messageListView
                        width: parent.width
                        model: ListModel {
                            id: messageHistory
                        }
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            width: messageListView.width
                            height: Math.max(40, messageContent.implicitHeight + 20)
                            color: index % 2 === 0 ? "#FAFAFA" : "white"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                Text {
                                    text: model.timestamp
                                    font.pixelSize: 11
                                    color: "#757575"
                                    Layout.preferredWidth: 80
                                    Layout.alignment: Qt.AlignTop
                                    verticalAlignment: Text.AlignTop
                                }

                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: 6
                                    color: model.type === "sent" ? "#2196F3" :
                                           model.type === "response" ? "#4CAF50" :
                                           model.type === "error" ? "#F44336" : "#FF9800"
                                }

                                Text {
                                    id: messageContent
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    text: model.content || ""
                                    font.pixelSize: 13
                                    color: model.type === "error" ? "#D32F2F" : "#424242"
                                    wrapMode: Text.Wrap
                                    elide: Text.ElideNone
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

        // Debug console section
        Rectangle {
            Layout.fillWidth: true
            height: 200
            color: tcpClient.connected ? "white" : "#F9F9F9"
            border.color: "#E0E0E0"
            border.width: 1
            radius: 4
            clip: false  // Allow title to show above border

            // Title background
            Rectangle {
                x: 8
                y: -12
                width: 130
                height: 24
                color: tcpClient.connected ? "white" : "#F9F9F9"
            }

            // Title label
            Text {
                x: 12
                y: -6
                text: "Debug Console"
                font.pixelSize: 14
                font.weight: Font.Medium
                color: tcpClient.connected ? "#424242" : "#9E9E9E"
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 20
                anchors.topMargin: 30
                spacing: 12
                height: 150

                // Command examples section
                Rectangle {
                    width: parent.width
                    height: 60
                    color: "#F8F9FA"
                    border.color: "#E9ECEF"
                    border.width: 1
                    radius: 4

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true

                        Text {
                            width: parent.width
                            text: "Essential Commands:\n• CANSEND#<CAN_ID>#<HEX_DATA>#<RATE_MS>#<CAN_BUS>  (e.g., CANSEND#0x123#DEADBEEF#100#vcan0)\n• LIST_TASKS  • LIST_CAN_INTERFACES  • KILL_TASK <task_id>  • PAUSE <task_id>  • RESUME <task_id>  • KILL_ALL_TASKS"
                            font.pixelSize: 11
                            font.family: "Monaco, Consolas, monospace"
                            color: "#495057"
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Text {
                    text: "Enter Command:"
                    font.pixelSize: 13
                    color: "#616161"
                    height: 20
                }

                Row {
                    width: parent.width
                    spacing: 10
                    height: 30

                    TextField {
                        id: messageField
                        width: parent.width - 90
                        height: 30
                        enabled: tcpClient.connected
                        selectByMouse: true
                        placeholderText: "Type command here (e.g., LIST_TASKS)"

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
                        width: 80
                        height: 30
                        enabled: tcpClient.connected && messageField.text.trim().length > 0

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
    }

    Component.onCompleted: {
        var settings = tcpClient.getSavedSettings()
        if (settings.length >= 2) {
            ipField.text = settings[0]
            portField.text = settings[1]
        }
    }
}
