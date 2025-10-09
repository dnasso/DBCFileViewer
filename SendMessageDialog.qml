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
    height: 750

    property string messageName: ""
    property string messageId: ""
    property string hexData: ""
    property int transmissionRate: 100 // Default rate in milliseconds
    property bool isSending: false
    property string lastStatusMessage: ""

    // Connection to handle message send status
    Connections {
        target: dbcParser
        function onMessageSendStatus(messageName, success, statusMessage) {
            if (messageName === sendMessageDialog.messageName) {
                statusText.text = statusMessage
                statusText.isSuccess = success
                sendMessageDialog.lastStatusMessage = statusMessage
                
                // Auto-hide success messages after 3 seconds
                if (success && statusMessage !== "Sending message...") {
                    statusHideTimer.start()
                }
                
                // Stop the sending state for non-"sending" messages
                if (statusMessage !== "Sending message...") {
                    sendMessageDialog.isSending = false
                }
            }
        }
    }

    // Timer to auto-hide status messages
    Timer {
        id: statusHideTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (statusText.isSuccess) {
                statusText.text = ""
            }
        }
    }

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
                Layout.alignment: Qt.AlignVCenter
                spacing: 6

                Text {
                    text: "Send CAN Message"
                    font.pixelSize: 22
                    font.weight: Font.Bold
                    color: "white"
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "Configure message transmission settings"
                    font.pixelSize: 14
                    color: "white"
                    opacity: 0.9
                    Layout.alignment: Qt.AlignHCenter
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

    // Connection to update hex data when signal values change
    Connections {
        target: dbcParser
        function onSignalModelChanged() {
            // Update hex data when signal values change
            if (sendMessageDialog.messageName) {
                sendMessageDialog.hexData = dbcParser.getMessageHexData(sendMessageDialog.messageName)
            }
        }
        function onGeneratedCanFrameChanged() {
            // Update hex data when CAN frame changes
            if (sendMessageDialog.messageName) {
                sendMessageDialog.hexData = dbcParser.getMessageHexData(sendMessageDialog.messageName)
            }
        }
        function onMessageModelChanged() {
            // Update hex data when message selection changes
            if (sendMessageDialog.messageName) {
                sendMessageDialog.hexData = dbcParser.getMessageHexData(sendMessageDialog.messageName)
            }
        }
    }

    onOpened: {
        // Update message information when dialog opens
        if (messageName) {
            messageId = "0x" + dbcParser.getMessageId(messageName).toString(16).toUpperCase()
            hexData = dbcParser.getMessageHexData(messageName)
        }
        
        // Update connection status
        updateConnectionStatus()
    }
    
    // Function to update connection status
    function updateConnectionStatus() {
        connectionStatusText.text = dbcParser.isConnectedToServer ? 
            "Connected to server" : "Not connected to server"
        connectionStatusText.color = dbcParser.isConnectedToServer ? 
            "#4CAF50" : "#F44336"
    }

    contentItem: ScrollView {
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AsNeeded
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            width: parent.width
            spacing: 20
            anchors.fill: parent
            anchors.margins: 20
            anchors.bottomMargin: 110

            // Message Information Section
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 160
                Layout.topMargin: 10
                color: "#F8F9FA"
                radius: 8
                border.color: "#E8F5E9"
                border.width: 2

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16

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
                        rowSpacing: 15
                        columnSpacing: 25

                        Text {
                            text: "Message Name:"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: "#424242"
                            Layout.preferredWidth: 120
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        }

                        Text {
                            text: sendMessageDialog.messageName
                            font.pixelSize: 14
                            color: "#616161"
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                            elide: Text.ElideRight
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            text: "CAN ID:"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: "#424242"
                            Layout.preferredWidth: 120
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        }

                        Text {
                            text: sendMessageDialog.messageId
                            font.pixelSize: 14
                            font.family: "Monospace"
                            color: "#616161"
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        }

                        Text {
                            text: "Hex Data:"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: "#424242"
                            Layout.preferredWidth: 120
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
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

            // Status message area (moved to top for immediate visibility)
            Rectangle {
                id: statusArea
                Layout.fillWidth: true
                Layout.preferredHeight: statusText.hasMessage ? 55 : 0
                color: statusText.isSuccess ? "#E8F5E8" : "#FFEBEE"
                border.color: statusText.isSuccess ? "#4CAF50" : "#F44336"
                border.width: statusText.hasMessage ? 1 : 0
                radius: 8
                visible: statusText.hasMessage

                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: 200 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        radius: 12
                        color: statusText.isSuccess ? "#4CAF50" : "#F44336"

                        Text {
                            anchors.centerIn: parent
                            text: statusText.isSuccess ? "✓" : "✗"
                            color: "white"
                            font.bold: true
                            font.pixelSize: 14
                        }
                    }

                    Text {
                        id: statusText
                        Layout.fillWidth: true
                        text: ""
                        font.pixelSize: 13
                        color: isSuccess ? "#2E7D32" : "#C62828"
                        wrapMode: Text.WordWrap

                        property bool hasMessage: text !== ""
                        property bool isSuccess: false
                    }

                    Button {
                        text: "×"
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        visible: statusText.hasMessage
                        
                        background: Rectangle {
                            color: parent.pressed ? "#FFCDD2" : (parent.hovered ? "#FFEBEE" : "transparent")
                            radius: 15
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "#666"
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            statusText.text = ""
                        }
                    }
                }
            }

            // Transmission Settings Section
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                color: "#F8F9FA"
                radius: 8
                border.color: "#E8F5E9"
                border.width: 2

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20

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
                        spacing: 20
                        Layout.alignment: Qt.AlignLeft

                        Text {
                            text: "Rate (ms):"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: "#424242"
                            Layout.preferredWidth: 100
                            Layout.alignment: Qt.AlignVCenter
                        }

                        SpinBox {
                            id: rateSpinBox
                            Layout.preferredWidth: 140
                            Layout.preferredHeight: 40
                            from: 1
                            to: 10000
                            value: sendMessageDialog.transmissionRate
                            editable: true
                            font.pixelSize: 14

                            onValueChanged: {
                                sendMessageDialog.transmissionRate = value
                            }

                            background: Rectangle {
                                color: "white"
                                radius: 6
                                border.color: parent.activeFocus ? "#4CAF50" : "#BDBDBD"
                                border.width: 1
                            }
                        }

                        Text {
                            text: "(" + (1000.0 / sendMessageDialog.transmissionRate).toFixed(1) + " Hz)"
                            font.pixelSize: 13
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

            // Server Connection Section
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                color: "#E3F2FD"
                radius: 8
                border.color: "#2196F3"
                border.width: 2

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16

                    Text {
                        text: "Server Connection"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: "#1976D2"
                        Layout.alignment: Qt.AlignLeft
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 20

                        Text {
                            id: connectionStatusText
                            text: "Not connected to server"
                            font.pixelSize: 14
                            color: "#F44336"
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Button {
                            text: dbcParser.isConnectedToServer ? "Disconnect" : "Connect"
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 40
                            enabled: !sendMessageDialog.isSending

                            background: Rectangle {
                                color: parent.pressed ? "#E3F2FD" : (parent.hovered ? "#F3E5F5" : "white")
                                border.color: "#2196F3"
                                border.width: 1
                                radius: 6
                            }

                            contentItem: Text {
                                text: parent.text
                                color: parent.enabled ? "#2196F3" : "#CCCCCC"
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                if (dbcParser.isConnectedToServer) {
                                    dbcParser.disconnectFromServer()
                                } else {
                                    // Try to connect with default values
                                    if (dbcParser.connectToServer("127.0.0.1", "8080")) {
                                        console.log("Connected to server successfully")
                                    } else {
                                        console.log("Failed to connect to server")
                                    }
                                }
                                updateConnectionStatus()
                            }
                        }
                    }
                }
            }

            // Message Preview Section
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                Layout.bottomMargin: 25
                color: "#FFF3E0"
                radius: 8
                border.color: "#FFB74D"
                border.width: 2

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16

                    Text {
                        text: "Message Preview"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: "#E65100"
                        Layout.alignment: Qt.AlignLeft
                    }

                    Text {
                        text: "Message to be sent:"
                        font.pixelSize: 13
                        color: "#BF360C"
                        Layout.alignment: Qt.AlignLeft
                        font.weight: Font.Medium
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 45
                        color: "white"
                        radius: 6
                        border.color: "#FFB74D"
                        border.width: 1

                        Text {
                            anchors.fill: parent
                            anchors.margins: 15
                            text: sendMessageDialog.messageId + " # " + sendMessageDialog.hexData + " # " + sendMessageDialog.transmissionRate + "ms"
                            font.family: "Monospace"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: "#E65100"
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        text: "Format: CAN_ID # HEX_DATA # RATE_MS"
                        font.pixelSize: 12
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
                enabled: !sendMessageDialog.isSending && dbcParser.isConnectedToServer

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
                    // Check if connected to server first
                    if (!dbcParser.isConnectedToServer) {
                        statusText.text = "Error: Not connected to server. Please connect first."
                        statusText.isSuccess = false
                        console.log("Not connected to server. Please connect first.")
                        return
                    }

                    // Clear previous status and show sending state
                    statusText.text = "Sending message..."
                    statusText.isSuccess = true
                    sendMessageDialog.isSending = true

                    // Call the backend method to send the message
                    var success = dbcParser.sendCanMessage(sendMessageDialog.messageName, sendMessageDialog.transmissionRate)
                    
                    if (success) {
                        console.log("Message send initiated:", sendMessageDialog.messageName, "at rate:", sendMessageDialog.transmissionRate, "ms")
                    } else {
                        console.log("Failed to initiate message send:", sendMessageDialog.messageName)
                        sendMessageDialog.isSending = false
                    }
                }
            }
        }
    }
}
