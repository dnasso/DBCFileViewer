import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Controls.Material
import TcpClient 1.0

ApplicationWindow {

    id: window
    visible: true
    width: 1920
    height: 1080
    title: "DBC File Viewer"
    
    // Apply Material theme
    Material.theme: Material.Light
    Material.accent: Material.Green
    Material.primary: Material.Green
    
    // Connect backend notification signals to frontend notification system
    Connections {
        target: dbcParser
        
        function onShowNotification(message, type) {
            showNotification(message, type)
        }
        
        function onShowError(message) {
            showError(message)
        }
        
        function onShowWarning(message) {
            showWarning(message)
        }
        
        function onShowSuccess(message) {
            showSuccess(message)
        }
        
        function onShowInfo(message) {
            showInfo(message)
        }
        
        function onMessageSendStatus(messageName, success, statusMessage) {
            if (success) {
                showSuccess("Message sent: " + messageName + " - " + statusMessage)
            } else {
                showError("Failed to send " + messageName + ": " + statusMessage)
            }
        }
        
        function onConnectionStatusChanged() {
            if (dbcParser.isConnectedToServer) {
                showSuccess("Connected to CAN server successfully!")
            } else {
                showWarning("Disconnected from CAN server")
            }
        }
        
        function onTransmissionStatusChanged(messageName, status) {
            var message = "Transmission " + messageName + " is now " + status
            if (status === "Active") {
                showSuccess(message)
            } else if (status === "Stopped") {
                showInfo(message)
            } else if (status === "Paused") {
                showWarning(message)
            }
        }
    }
    
    // Global notification functions - accessible from anywhere in this file
    function showNotification(message, type) {
        type = type || "info"
        console.log("Showing notification:", type, "-", message)
        
        var notification = notificationComponent.createObject(notificationColumn, {
            "message": message,
            "type": type
        })
    }
    
    function showError(message) {
        showNotification(message, "error")
    }
    
    function showWarning(message) {
        showNotification(message, "warning")
    }
    
    function showSuccess(message) {
        showNotification(message, "success")
    }
    
    function showInfo(message) {
        showNotification(message, "info")
    }
    
    // Legacy function for backward compatibility
    function showStatusMessage(message, isError) {
        if (isError) {
            showError(message)
        } else {
            showSuccess(message)
        }
    }
    
    // File dialog for loading DBC files
    FileDialog {
        id: fileDialog
        title: "Select a DBC File"
        nameFilters: ["DBC Files (*.dbc)"]
        onAccepted: {
            dbcParser.loadDbcFile(selectedFile)
            statusText.text = "DBC file loaded: " + selectedFile
        }
    }
    
    // Main layout with header and content
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // Header with green background
        Rectangle {
            id: header
            Layout.fillWidth: true
            height: 50
            color: "#4CAF50" // Green header
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                
                Text {
                    text: "DBC File Viewer"
                    font.pixelSize: 18
                    font.bold: true
                    color: "white"
                }
                
                // Connection Status Indicator
                Rectangle {
                    id: connectionStatusIndicator
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 30
                    color: getConnectionStatus() ? "#2E7D32" : "#D32F2F"
                    radius: 15
                    border.color: "white"
                    border.width: 1
                    
                    // Function to get connection status from multiple sources
                    function getConnectionStatus() {
                        var status = dbcParser.isConnectedToServer || 
                               (tcpClientTab && tcpClientTab.tcpClient && tcpClientTab.tcpClient.connected)
                        return status
                    }
                    
                    // Property change notifications
                    Connections {
                        target: dbcParser
                        function onIsConnectedToServerChanged() {
                            connectionStatusIndicator.color = connectionStatusIndicator.getConnectionStatus() ? "#2E7D32" : "#D32F2F"
                        }
                    }
                    
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 5
                        
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: "white"
                            
                            SequentialAnimation on opacity {
                                running: connectionStatusIndicator.getConnectionStatus()
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 800 }
                                NumberAnimation { to: 1.0; duration: 800 }
                            }
                        }
                        
                        Text {
                            text: connectionStatusIndicator.getConnectionStatus() ? "Connected" : "Disconnected"
                            color: "white"
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (!connectionStatusIndicator.getConnectionStatus()) {
                                // Try to connect via the TCP client first
                                if (tcpClientTab && tcpClientTab.tcpClient) {
                                    tcpClientTab.tcpClient.connectToServer("127.0.0.1", 8080)
                                } else {
                                    dbcParser.connectToServer("127.0.0.1", "8080")
                                }
                            }
                        }
                        
                        ToolTip.visible: hovered
                        ToolTip.text: connectionStatusIndicator.getConnectionStatus() ? 
                              "Connected to CAN receiver (127.0.0.1:8080)" : 
                              "Click to connect to CAN receiver"
                        ToolTip.delay: 500
                    }
                }
                
                Item { Layout.fillWidth: true }
                Button {
                    text: "Download DBC File"

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        implicitWidth: 140
                        implicitHeight: 36
                        color: parent.hovered ? Qt.lighter("#388E3C", 1.1) : "#388E3C"
                        radius: 4
                    }

                    onClicked: {
                        diffDialog.showDiff()
                    }
                }

                Button {
                    text: "Load DBC File"
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    background: Rectangle {
                        implicitWidth: 120
                        implicitHeight: 36
                        color: parent.hovered ? Qt.lighter("#388E3C", 1.1) : "#388E3C"
                        radius: 4
                    }
                    
                    onClicked: fileDialog.open()
                }
            }
        }
        
        // Status text
        Text {
            id: statusText
            Layout.fillWidth: true
            Layout.margins: 10
            text: "No DBC file loaded"
            color: "#757575"
        }
        
        // Main content area with tabs
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            
            // Tab bar
            TabBar {
                id: tabBar
                Layout.fillWidth: true
                
                TabButton {
                    text: "DBC Editor"
                    width: implicitWidth
                }
                
                TabButton {
                    text: "Active Transmissions"
                    width: implicitWidth
                }
                
                TabButton {
                    text: "Client"
                    width: implicitWidth
                }
            }
            
            // Tab content
            SplitView {
                id: mainSplitView
                Layout.fillWidth: true
                Layout.fillHeight: true
                orientation: Qt.Vertical
                visible: tabBar.currentIndex === 0
            
            // Top section with messages and signals
            SplitView {
                id: topSplitView
                SplitView.fillHeight: true
                SplitView.minimumHeight: 300
                orientation: Qt.Horizontal
                
                // Messages panel
                Rectangle {
                    id: messagesPanel
                    SplitView.preferredWidth: 350
                    SplitView.minimumWidth: 250
                    color: "white"
                    
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0
                        
                        // Panel header with buttons - FIXED ALIGNMENT
                        Rectangle {
                            Layout.fillWidth: true
                            height: 45
                            color: "#FAFAFA"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 15
                                anchors.rightMargin: 15
                                spacing: 10

                                // Add button with icon
                                Button {
                                    id: addMessageBtn
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32

                                    contentItem: Text {
                                        text: "+"
                                        color: "#4CAF50"
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.pixelSize: 20
                                        font.weight: Font.Medium
                                        anchors.centerIn: parent
                                    }

                                    background: Rectangle {
                                        radius: 16
                                        color: parent.pressed ? "#E8F5E9" : (parent.hovered ? "#F1F8E9" : "transparent")
                                        border.color: parent.hovered ? "#4CAF50" : "transparent"
                                        border.width: parent.hovered ? 1 : 0
                                        anchors.fill: parent
                                    }

                                    ToolTip {
                                        visible: parent.hovered
                                        text: "Add new CAN message"
                                        delay: 500
                                        background: Rectangle {
                                            color: "#424242"
                                            radius: 4
                                        }
                                        contentItem: Text {
                                            text: parent.text
                                            color: "white"
                                            font.pixelSize: 12
                                        }
                                    }

                                    onClicked: {
                                        addMessageDialog.open()
                                    }
                                }

                                Text {
                                    text: "CAN Messages"
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    color: "#2E7D32"
                                    // REMOVED: Layout.fillWidth: true
                                }

                                Item { Layout.fillWidth: true } // ← ADDED THIS

                                // Remove button with icon
                                Button {
                                    id: removeMessageBtn
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    enabled: messageListView.currentIndex >= 0
                                    opacity: enabled ? 1.0 : 0.5

                                    contentItem: Text {
                                        text: "−"
                                        color: "#F44336"
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.pixelSize: 20
                                        font.weight: Font.Medium
                                        anchors.centerIn: parent
                                    }

                                    background: Rectangle {
                                        radius: 16
                                        color: parent.pressed ? "#FFEBEE" : (parent.hovered && parent.enabled ? "#FFF3E0" : "transparent")
                                        border.color: parent.hovered && parent.enabled ? "#F44336" : "transparent"
                                        border.width: parent.hovered && parent.enabled ? 1 : 0
                                        anchors.fill: parent
                                    }

                                    ToolTip {
                                        visible: parent.hovered && parent.enabled
                                        text: "Remove selected message"
                                        delay: 500
                                        background: Rectangle {
                                            color: "#424242"
                                            radius: 4
                                        }
                                        contentItem: Text {
                                            text: parent.text
                                            color: "white"
                                            font.pixelSize: 12
                                        }
                                    }

                                    onClicked: {
                                        if (messageListView.currentIndex >= 0) {
                                            var selectedMsg = dbcParser.messageModel[messageListView.currentIndex]
                                            var msgName = selectedMsg.split(" (")[0]
                                            removeMessageConfirmDialog.messageName = msgName
                                            removeMessageConfirmDialog.open()
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 1
                                color: "#E0E0E0"
                            }
                        }
                        
                        // Messages list
                        ListView {
                            id: messageListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: dbcParser.messageModel
                            
                            // Add scrollbar
                            ScrollBar.vertical: ScrollBar {
                                active: true
                                policy: ScrollBar.AsNeeded
                            }
                            
                            delegate: Rectangle {
                                width: messageListView.width
                                height: 50 // Increased height to accommodate send button
                                color: highlighted ? "#E8F5E9" : (index % 2 == 0 ? "#F5F5F5" : "white")

                                property bool highlighted: ListView.isCurrentItem

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    // Message text (takes most of the space)
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData
                                        verticalAlignment: Text.AlignVCenter
                                        color: highlighted ? "#2E7D32" : "#424242"
                                        font.weight: highlighted ? Font.Medium : Font.Normal
                                        elide: Text.ElideRight
                                    }

                                    // Send button
                                    Button {
                                        id: sendMessageBtn
                                        Layout.preferredWidth: 60
                                        Layout.preferredHeight: 32
                                        text: "Send"

                                        contentItem: Text {
                                            text: parent.text
                                            color: "#4CAF50"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                        }

                                        background: Rectangle {
                                            color: parent.pressed ? "#E8F5E9" :
                                                   (parent.hovered ? "#F1F8E9" : "transparent")
                                            border.color: "#4CAF50"
                                            border.width: 1
                                            radius: 4

                                            Behavior on color {
                                                ColorAnimation { duration: 100 }
                                            }
                                        }

                                        ToolTip {
                                            visible: parent.hovered
                                            text: "Send this CAN message"
                                            delay: 500
                                            background: Rectangle {
                                                color: "#424242"
                                                radius: 4
                                            }
                                            contentItem: Text {
                                                text: parent.text
                                                color: "white"
                                                font.pixelSize: 12
                                            }
                                        }

                                        onClicked: {
                                            // Set the current message as selected
                                            messageListView.currentIndex = index
                                            dbcParser.selectMessage(modelData)

                                            // Open the send message dialog
                                            sendMessageDialog.messageName = modelData
                                            sendMessageDialog.open()
                                        }
                                    }
                                }

                                // Click handler for the message text area
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.rightMargin: 80 // Leave space for send button
                                    onClicked: {
                                        messageListView.currentIndex = index
                                        dbcParser.selectMessage(modelData)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Signals panel with horizontal scrolling
                Rectangle {
                    id: signalsPanel
                    SplitView.fillWidth: true
                    SplitView.minimumWidth: 600
                    color: "white"

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        // Panel header with buttons - FIXED ALIGNMENT
                        Rectangle {
                            Layout.fillWidth: true
                            height: 45
                            color: "#FAFAFA"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 15
                                anchors.rightMargin: 15
                                spacing: 10

                                // Add button
                                Button {
                                    id: addSignalBtn
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    enabled: messageListView.currentIndex >= 0
                                    opacity: enabled ? 1.0 : 0.5

                                    contentItem: Text {
                                        text: "+"
                                        color: "#4CAF50"
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.pixelSize: 20
                                        font.weight: Font.Medium
                                        anchors.centerIn: parent
                                    }

                                    background: Rectangle {
                                        radius: 16
                                        color: parent.pressed && parent.enabled ? "#E8F5E9" :
                                               (parent.hovered && parent.enabled ? "#F1F8E9" : "transparent")
                                        border.color: parent.hovered && parent.enabled ? "#4CAF50" : "transparent"
                                        border.width: parent.hovered && parent.enabled ? 1 : 0
                                        anchors.fill: parent
                                    }

                                    ToolTip {
                                        visible: parent.hovered && parent.enabled
                                        text: "Add new signal to selected message"
                                        delay: 500
                                        background: Rectangle {
                                            color: "#424242"
                                            radius: 4
                                        }
                                        contentItem: Text {
                                            text: parent.text
                                            color: "white"
                                            font.pixelSize: 12
                                        }
                                    }

                                    onClicked: {
                                        if (messageListView.currentIndex >= 0) {
                                            var selectedMsg = dbcParser.messageModel[messageListView.currentIndex]
                                            var msgName = selectedMsg.split(" (")[0]
                                            addSignalDialog.currentMessageName = msgName
                                            addSignalDialog.open()
                                        }
                                    }
                                }

                                Text {
                                    text: "Signal Details"
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    color: "#2E7D32"
                                    // REMOVED: Layout.fillWidth: true
                                }

                                Item { Layout.fillWidth: true } // ← ADDED THIS

                                // Remove button
                                Button {
                                    id: removeSignalBtn
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    enabled: signalListView.currentIndex >= 0 && messageListView.currentIndex >= 0
                                    opacity: enabled ? 1.0 : 0.5

                                    contentItem: Text {
                                        text: "−"
                                        color: "#F44336"
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.pixelSize: 20
                                        font.weight: Font.Medium
                                        anchors.centerIn: parent
                                    }

                                    background: Rectangle {
                                        radius: 16
                                        color: parent.pressed && parent.enabled ? "#FFEBEE" :
                                               (parent.hovered && parent.enabled ? "#FFF3E0" : "transparent")
                                        border.color: parent.hovered && parent.enabled ? "#F44336" : "transparent"
                                        border.width: parent.hovered && parent.enabled ? 1 : 0
                                        anchors.fill: parent
                                    }

                                    ToolTip {
                                        visible: parent.hovered && parent.enabled
                                        text: "Remove selected signal"
                                        delay: 500
                                        background: Rectangle {
                                            color: "#424242"
                                            radius: 4
                                        }
                                        contentItem: Text {
                                            text: parent.text
                                            color: "white"
                                            font.pixelSize: 12
                                        }
                                    }

                                    onClicked: {
                                        if (signalListView.currentIndex >= 0 && messageListView.currentIndex >= 0) {
                                            var selectedMsg = dbcParser.messageModel[messageListView.currentIndex]
                                            var msgName = selectedMsg.split(" (")[0]
                                            var signalData = dbcParser.signalModel[signalListView.currentIndex]
                                            removeSignalConfirmDialog.messageName = msgName
                                            removeSignalConfirmDialog.signalName = signalData.name
                                            removeSignalConfirmDialog.open()
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 1
                                color: "#E0E0E0"
                            }
                        }
                        
                        // Scrollable signal details
                        ScrollView {
                            id: signalScrollView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOn
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded
                            
                            // Table header
                            Item {
                                width: Math.max(signalScrollView.width, signalTableRow.width)
                                height: signalListView.height + 40 // Header height + ListView height
                                
                                // Fixed header that stays at the top
                                Rectangle {
                                    id: signalTableHeader
                                    width: parent.width
                                    height: 40
                                    color: "#F5F5F5"
                                    z: 2
                                    
                                    // Header row
                                    Row {
                                        id: signalTableRow
                                        height: parent.height
                                        width: childrenRect.width
                                        
                                        // Header cells
                                        Repeater {
                                            model: [
                                                { name: "Name", width: 170 },
                                                { name: "Type", width: 120 },
                                                { name: "Start", width: 100 },
                                                { name: "Length", width: 100 },
                                                { name: "Factor", width: 100 },
                                                { name: "Offset", width: 100 },
                                                { name: "Min", width: 100 },
                                                { name: "Max", width: 100 },
                                                { name: "Unit", width: 100 },
                                                { name: "Value", width: 180 }
                                            ]
                                            
                                            Rectangle {
                                                width: modelData.width
                                                height: parent.height
                                                color: "transparent"
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.name
                                                    font.bold: true
                                                }
                                                
                                                Rectangle {
                                                    width: 1
                                                    height: parent.height
                                                    anchors.right: parent.right
                                                    color: "#E0E0E0"
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // Table content ListView
                                ListView {
                                    id: signalListView
                                    y: signalTableHeader.height
                                    width: parent.width
                                    height: signalScrollView.height - signalTableHeader.height
                                    clip: true
                                    model: dbcParser.signalModel
                                    
                                    // Add scrollbar
                                    ScrollBar.vertical: ScrollBar {
                                        active: true
                                        policy: ScrollBar.AsNeeded
                                    }
                                    
                                    delegate: Rectangle {
                                        width: signalListView.width
                                        height: 45
                                        color: index % 2 == 0 ? "#F5F5F5" : "white"
                                        
                                        // Signal row content
                                        Row {
                                            id: signalTableRow
                                            width: parent.width // Fix width calculation
                                            height: parent.height
                                            spacing: 0
                                            
                                            // Name field
                                            Rectangle {
                                                width: 180
                                                height: parent.height
                                                color: "transparent"
                                                
                                                TextField {
                                                    anchors.fill: parent
                                                    anchors.margins: 5
                                                    text: modelData.name
                                                    readOnly: true
                                                    background: Rectangle {
                                                        color: "transparent"
                                                        border.color: "transparent"
                                                    }
                                                }
                                                
                                                Rectangle {
                                                    width: 1
                                                    height: parent.height
                                                    anchors.right: parent.right
                                                    color: "#E0E0E0"
                                                }
                                            }
                                            
                                            // Type field
                                            Rectangle {
                                                width: 120
                                                height: parent.height
                                                color: "transparent"
                                                
                                                ComboBox {
                                                    anchors.fill: parent
                                                    anchors.margins: 5
                                                    model: ["Unsigned", "Signed"]
                                                    currentIndex: 0
                                                }
                                                
                                                Rectangle {
                                                    width: 1
                                                    height: parent.height
                                                    anchors.right: parent.right
                                                    color: "#E0E0E0"
                                                }
                                            }
                                            
                                            // Start bit field
                                            Rectangle {
                                                width: 100
                                                height: parent.height
                                                color: "transparent"
                                                
                                                SpinBox {
                                                    anchors.fill: parent
                                                    anchors.margins: 5
                                                    from: 0
                                                    to: 63
                                                    value: modelData.startBit
                                                    editable: true
                                                    
                                                    // Add change handler to update signal parameter
                                                    onValueChanged: {
                                                        // Signal change to C++ backend
                                                        dbcParser.updateSignalParameter(modelData.name, "startBit", value)
                                                    }
                                                }
                                                
                                                Rectangle {
                                                    width: 1
                                                    height: parent.height
                                                    anchors.right: parent.right
                                                    color: "#E0E0E0"
                                                }
                                            }
                                            
                                            // Length field
                                            Rectangle {
                                                width: 100
                                                height: parent.height
                                                color: "transparent"
                                                
                                                SpinBox {
                                                    anchors.fill: parent
                                                    anchors.margins: 5
                                                    from: 1
                                                    to: 64
                                                    value: modelData.length
                                                    editable: true
                                                    
                                                    // Add change handler to update signal parameter
                                                    onValueChanged: {
                                                        // Signal change to C++ backend
                                                        dbcParser.updateSignalParameter(modelData.name, "length", value)
                                                    }
                                                }
                                                
                                                Rectangle {
                                                    width: 1
                                                    height: parent.height
                                                    anchors.right: parent.right
                                                    color: "#E0E0E0"
                                                }
                                            }
                                            
                                            // Factor field
                                            Rectangle {
                                                width: 100
                                                height: parent.height
                                                color: "transparent"
                                                
                                                TextField {
                                                    id: factorField
                                                    anchors.fill: parent
                                                    anchors.margins: 5
                                                    text: modelData.factor.toString()
                                                    validator: DoubleValidator {
                                                        notation: DoubleValidator.StandardNotation
                                                    }
                                                    
                                                    // Update factor when editing is completed
                                                    onEditingFinished: {
                                                        if (text.length > 0) {
                                                            dbcParser.updateSignalParameter(modelData.name, "factor", parseFloat(text))
                                                            // Force update of the physical value calculation
                                                            if (bitsSection.signalName === modelData.name) {
                                                                bitsSection.updateCalculationText()
                                                            }
                                                        }
                                                    }
                                                }
                                                
                                                Rectangle {
                                                    width: 1
                                                    height: parent.height
                                                    anchors.right: parent.right
                                                    color: "#E0E0E0"
                                                }
                                            }
                                            
                                            // Offset field
                                            Rectangle {
                                                width: 100
                                                height: parent.height
                                                color: "transparent"
                                                
                                                TextField {
                                                    id: offsetField
                                                    anchors.fill: parent
                                                    anchors.margins: 5
                                                    text: modelData.offset.toString()
                                                    validator: DoubleValidator {
                                                        notation: DoubleValidator.StandardNotation
                                                    }
                                                    
                                                    // Update offset when editing is completed
                                                    onEditingFinished: {
                                                        if (text.length > 0) {
                                                            dbcParser.updateSignalParameter(modelData.name, "offset", parseFloat(text))
                                                            // Force update of the physical value calculation
                                                            if (bitsSection.signalName === modelData.name) {
                                                                bitsSection.updateCalculationText()
                                                            }
                                                        }
                                                    }
                                                }
                                                
                                                Rectangle {
                                                    width: 1
                                                    height: parent.height
                                                    anchors.right: parent.right
                                                    color: "#E0E0E0"
                                                }
                                            }
                                            
                                            // Min field
                                            Rectangle {
                                                width: 100
                                                height: parent.height
                                                color: "transparent"
                                                
                                                TextField {
                                                    anchors.fill: parent
                                                    anchors.margins: 5
                                                    text: modelData.min.toString()
                                                    validator: DoubleValidator {
                                                        notation: DoubleValidator.StandardNotation
                                                    }
                                                    
                                                    // Update min when editing is completed
                                                    onEditingFinished: {
                                                        if (text.length > 0) {
                                                            dbcParser.updateSignalParameter(modelData.name, "min", parseFloat(text))
                                                        }
                                                    }
                                                }
                                                
                                                Rectangle {
                                                    width: 1
                                                    height: parent.height
                                                    anchors.right: parent.right
                                                    color: "#E0E0E0"
                                                }
                                            }
                                            
                                            // Max field
                                            Rectangle {
                                                width: 100
                                                height: parent.height
                                                color: "transparent"
                                                
                                                TextField {
                                                    anchors.fill: parent
                                                    anchors.margins: 5
                                                    text: modelData.max.toString()
                                                    validator: DoubleValidator {
                                                        notation: DoubleValidator.StandardNotation
                                                    }
                                                    
                                                    // Update max when editing is completed
                                                    onEditingFinished: {
                                                        if (text.length > 0) {
                                                            dbcParser.updateSignalParameter(modelData.name, "max", parseFloat(text))
                                                        }
                                                    }
                                                }
                                                
                                                Rectangle {
                                                    width: 1
                                                    height: parent.height
                                                    anchors.right: parent.right
                                                    color: "#E0E0E0"
                                                }
                                            }
                                            
                                            // Unit field
                                            Rectangle {
                                                width: 100
                                                height: parent.height
                                                color: "transparent"
                                                
                                                TextField {
                                                    anchors.fill: parent
                                                    anchors.margins: 5
                                                    text: modelData.unit
                                                    
                                                    // Update unit when editing is completed
                                                    onEditingFinished: {
                                                        dbcParser.updateSignalParameter(modelData.name, "unit", text)
                                                        // Force update of the physical value calculation
                                                        if (bitsSection.signalName === modelData.name) {
                                                            bitsSection.updateCalculationText()
                                                        }
                                                    }
                                                }
                                                
                                                Rectangle {
                                                    width: 1
                                                    height: parent.height
                                                    anchors.right: parent.right
                                                    color: "#E0E0E0"
                                                }
                                            }
                                            
                                            // Value field with Bits button
                                            Rectangle {
                                                width: 165
                                                height: parent.height
                                                color: "transparent"
                                                
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 4
                                                    spacing: 4
                                                    
                                                    SpinBox {
                                                        id: valueSpinBox
                                                        Layout.fillWidth: true
                                                        Layout.fillHeight: true
                                                        from: modelData.min !== modelData.max ? modelData.min : -999999
                                                        to: modelData.min !== modelData.max ? modelData.max : 999999
                                                        value: modelData.value
                                                        editable: true
                                                        stepSize: 1
                                                        onValueChanged: {
                                                            dbcParser.updateSignalValue(modelData.name, value)
                                                            
                                                            // If the bits section is showing this signal, update it
                                                            if (bitsSection.signalName === modelData.name) {
                                                                bitsSection.signalValue = value
                                                                bitsSection.updateBitDisplay()
                                                                bitsSection.updateCalculationText()
                                                                bitsSection.updateDataDisplay()
                                                            }
                                                        }
                                                    }
                                                    
                                                    Button {
                                                        Layout.preferredWidth: 60
                                                        Layout.preferredHeight: 32
                                                        text: "Bits"
                                                        z: 10 // Higher z-index to ensure it's clickable
                                                        hoverEnabled: true

                                                        contentItem: Text {
                                                            text: parent.text
                                                            color: parent.hovered ? "white" : "#4CAF50"
                                                            horizontalAlignment: Text.AlignHCenter
                                                            verticalAlignment: Text.AlignVCenter
                                                            font.pixelSize: 12
                                                            font.weight: Font.Bold
                                                            anchors.centerIn: parent
                                                        }

                                                        background: Rectangle {
                                                            anchors.fill: parent
                                                            color: parent.pressed ? "#2E7D32" :
                                                                   (parent.hovered ? "#4CAF50" : "transparent")
                                                            border.color: "#4CAF50"
                                                            border.width: 2
                                                            radius: 6

                                                            // Glow effect on hover
                                                            Rectangle {
                                                                anchors.fill: parent
                                                                color: "transparent"
                                                                border.color: "#81C784"
                                                                border.width: parent.parent.hovered ? 3 : 0
                                                                radius: 6
                                                                opacity: parent.parent.hovered ? 0.8 : 0
                                                                
                                                                Behavior on opacity {
                                                                    NumberAnimation { duration: 150 }
                                                                }
                                                                
                                                                Behavior on border.width {
                                                                    NumberAnimation { duration: 150 }
                                                                }
                                                            }

                                                            Behavior on color {
                                                                ColorAnimation { duration: 200 }
                                                            }
                                                        }

                                                        // Enhanced mouse area to ensure full button is clickable
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                signalListView.currentIndex = index
                                                                bitsSection.signalName = modelData.name
                                                                // Get the current value from the backend instead of cached modelData
                                                                bitsSection.signalValue = dbcParser.getSignalValue(modelData.name)
                                                                bitsSection.signalStartBit = modelData.startBit
                                                                bitsSection.signalLength = modelData.length
                                                                bitsSection.signalLittleEndian = modelData.littleEndian
                                                                bitsSection.visible = true
                                                                bitsSection.initializeDisplay()
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // Highlight selected item
                                        Rectangle {
                                            anchors.fill: parent
                                            color: signalListView.currentIndex === index ? "#E8F5E9" : "transparent"
                                            opacity: 0.5
                                            z: -1
                                        }
                                                          MouseArea {
                            anchors.fill: parent
                            anchors.rightMargin: 70 // Leave space for the Bits button column
                            hoverEnabled: false // Disable hover to prevent interference
                            onClicked: {
                                signalListView.currentIndex = index
                            }
                            z: -2 // Behind other controls
                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            

            // Bits Section - Replaces the Generated Frame section
            Rectangle {
                id: bitsSection
                SplitView.fillHeight: true
                SplitView.minimumHeight: 350
                color: "#f9f9f9"
                visible: true
                
                property string signalName: ""
                property double signalValue: 0
                property int signalStartBit: 0
                property int signalLength: 0
                property bool signalLittleEndian: true
                property var bitValues: []
                property double rawValue: 0
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    
                    // Header
                    Rectangle {
                        Layout.fillWidth: true
                        height: 30
                        color: "white"
                        
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "CAN signal preview: " + bitsSection.signalName
                            font.pixelSize: 16
                            font.bold: true
                            color: "#4CAF50"
                        }
                        
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: "#E0E0E0"
                        }
                    }
                    
                    // Value display row
                    Rectangle {
                        Layout.fillWidth: true
                        height: 70
                        color: "white"
                        border.color: "#e0e0e0"
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 15
                            
                            Text {
                                text: "Physical Value:"
                                font.pixelSize: 13
                            }
                            
                            TextField {
                                id: physicalValueField
                                Layout.preferredWidth: 120
                                text: bitsSection.signalValue.toString()
                                validator: DoubleValidator {}
                                selectByMouse: true
                                onTextChanged: {
                                    if (activeFocus && text && text.length > 0) {
                                        var physValue = parseFloat(text);
                                        bitsSection.signalValue = physValue;
                                        bitsSection.rawValue = dbcParser.calculateRawValue(bitsSection.signalName, physValue);
                                        rawValueField.text = Math.round(bitsSection.rawValue).toString();
                                        dbcParser.updateSignalValue(bitsSection.signalName, physValue);
                                        updateCalculationText();
                                        updateBitDisplay();
                                        updateDataDisplay();
                                    }
                                }
                            }
                            
                            Text {
                                text: "Raw Value:"
                                font.pixelSize: 13
                            }
                            
                            TextField {
                                id: rawValueField
                                Layout.preferredWidth: 120
                                text: "0"
                                validator: IntValidator {}
                                selectByMouse: true
                                onTextChanged: {
                                    if (activeFocus && text && text.length > 0) {
                                        bitsSection.rawValue = parseInt(text);
                                        var physValue = dbcParser.calculatePhysicalValue(bitsSection.signalName, bitsSection.rawValue);
                                        bitsSection.signalValue = physValue;
                                        physicalValueField.text = physValue.toString();
                                        dbcParser.updateSignalFromRawValue(bitsSection.signalName, bitsSection.rawValue);
                                        updateCalculationText();
                                        updateBitDisplay();
                                        updateDataDisplay();
                                    }
                                }
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                                ComboBox {
                                id: displayMode
                                model: ["Decimal", "Hexadecimal", "Binary"]
                                currentIndex: 0
                                onCurrentIndexChanged: updateBitDisplay()
                            }
                        }
                    }
                    
                    // Bit editor content
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 2
                        rowSpacing: 10
                        columnSpacing: 10
                        
                        // First column: Bit indices display
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "white"
                            border.color: "#e0e0e0"
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 5
                                
                                Text {
                                    text: "Editor bit indices"
                                    font.pixelSize: 14
                                    font.bold: true
                                    Layout.alignment: Qt.AlignLeft
                                }
                                
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    
                                    // Main grid for bit indices
                                    Grid {
                                        id: bitIndicesGrid
                                        anchors.fill: parent
                                        anchors.margins: 5
                                        columns: 9
                                        columnSpacing: 1
                                        rowSpacing: 1
                                        
                                        // Empty top-left cell
                                        Rectangle {
                                            width: 30
                                            height: 30
                                            color: "transparent"
                                        }
                                        
                                        // Column headers (bit positions 7-0)
                                        Repeater {
                                            model: 8
                                            Rectangle {
                                                width: 30
                                                height: 30
                                                color: "#e0e0e0"
                                                border.color: "#cccccc"
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: 7 - index
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                }
                                            }
                                        }
                                        
                                        // Generate the grid with row headers and bit cells
                                        Repeater {
                                            model: 72 // 8 rows * 9 cells (1 row header + 8 bit cells)
                                            
                                            Rectangle {
                                                id: gridCell
                                                width: 30
                                                height: 30
                                                property int row: Math.floor(index / 9)
                                                property int col: index % 9
                                                property bool isHeader: col === 0
                                                property bool isDataCell: !isHeader
                                                property int byteIdx: row
                                                property int bitIdx: isDataCell ? 7 - (col - 1) : 0
                                                property int bitPosition: isDataCell ? byteIdx * 8 + bitIdx : 0
                                                property bool isPartOfSignal: isDataCell ? false : false
                                                property bool bitValue: false
                                                
                                                color: isHeader ? "#e0e0e0" : (isPartOfSignal ? (bitValue ? "#81C784" : "#E8F5E9") : "#f5f5f5")
                                                border.color: "#cccccc"
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: gridCell.isHeader ? gridCell.row : 
                                                        (gridCell.isPartOfSignal ? (gridCell.bitValue ? "1" : "0") : 
                                                        gridCell.bitPosition.toString())
                                                    font.pixelSize: 12
                                                    font.bold: gridCell.isHeader
                                                    color: gridCell.isHeader ? "black" : 
                                                        (gridCell.isPartOfSignal ? "#2E7D32" : "#757575")
                                                }
                                                
                                                // Set object name for finding cells later
                                                Component.onCompleted: {
                                                    if (isDataCell) {
                                                        objectName = "bitCell_" + byteIdx + "_" + bitIdx;
                                                    }
                                                }
                                                
                                                // Mouse area for bit toggling
                                                MouseArea {
                                                    anchors.fill: parent
                                                    enabled: gridCell.isDataCell
                                                    onClicked: {
                                                        if (gridCell.isPartOfSignal) {
                                                            toggleBit(gridCell.byteIdx, gridCell.bitIdx);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Second column: Data calculation and bit values display
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "white"
                            border.color: "#e0e0e0"
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10
                                
                                Text {
                                    text: "CAN frame"
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                                
                                // Data display with bit values
                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    rowSpacing: 5
                                    columnSpacing: 10
                                    
                                    Text { 
                                        text: "Data (HEX):" 
                                        font.pixelSize: 12
                                    }
                                    
                                    TextField {
                                        id: hexDataField
                                        Layout.fillWidth: true
                                        readOnly: true
                                        text: ""
                                        font.family: "Monaco"
                                    }
                                    
                                    Text { 
                                        text: "Data (BIN):" 
                                        font.pixelSize: 12
                                    }
                                    
                                    TextField {
                                        id: binDataField
                                        Layout.fillWidth: true
                                        readOnly: true
                                        text: ""
                                        font.family: "Monaco"
                                    }
                                }
                                
                                // Spacer
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                }
                                
                                // Data calculation display
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 80
                                    color: "#f5f5f5"
                                    border.color: "#e0e0e0"
                                    
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 5
                                        
                                        Text {
                                            id: dataValueText
                                            text: "Data = 0x00 = 0"
                                            font.family: "Monaco"
                                            font.pixelSize: 14
                                        }
                                        
                                        Text {
                                            id: physicalValueText
                                            text: "Physical value = 1.0 * 0 + 0 = 0"
                                            font.family: "Monaco"
                                            font.pixelSize: 14
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Functions for bit manipulation
                function initializeDisplay() {
                    // Clear any existing bit values
                    bitsSection.bitValues = [];
                    
                    // Get raw value from the current signal value
                    bitsSection.rawValue = dbcParser.calculateRawValue(bitsSection.signalName, bitsSection.signalValue);
                    rawValueField.text = Math.round(bitsSection.rawValue).toString();
                    
                    // Update calculation text
                    updateCalculationText();
                    
                    // Update bit display
                    updateBitDisplay();
                    
                    // Update hex and binary display
                    updateDataDisplay();
                }
                
                function updateCalculationText() {
                    var calculationText = dbcParser.formatPhysicalValueCalculation(bitsSection.signalName, bitsSection.rawValue);
                    var lines = calculationText.split('\n');
                    
                    if (lines.length >= 2) {
                        dataValueText.text = lines[0];
                        physicalValueText.text = lines[1];
                    }
                }
                
                function updateDataDisplay() {
                    // Get the frame data as hex and binary using the unified methods
                    var hexData = dbcParser.getCurrentMessageHexData();
                    var binData = dbcParser.getCurrentMessageBinData();
                    
                    hexDataField.text = hexData;
                    binDataField.text = binData;
                }
                
                function findBitCell(row, col) {
                    // Find a bit cell by its row and column in the grid
                    for (let i = 0; i < bitIndicesGrid.children.length; i++) {
                        let child = bitIndicesGrid.children[i];
                        if (child.objectName === "bitCell_" + row + "_" + col) {
                            return child;
                        }
                    }
                    return null;
                }
                
                function toggleBit(row, col) {
                    // Toggle a bit when clicked
                    let cell = findBitCell(row, col);
                    if (cell && cell.isPartOfSignal) {
                        // Toggle the bit value
                        let newBitValue = !cell.bitValue;
                        
                        // Update the bit in the backend
                        dbcParser.setBit(bitsSection.signalName, row, col, newBitValue);
                        
                        // Recalculate raw value
                        bitsSection.rawValue = dbcParser.calculateRawValue(bitsSection.signalName, bitsSection.signalValue);
                        rawValueField.text = Math.round(bitsSection.rawValue).toString();
                        
                        // Update physical value
                        var physValue = dbcParser.calculatePhysicalValue(bitsSection.signalName, bitsSection.rawValue);
                        bitsSection.signalValue = physValue;
                        physicalValueField.text = physValue.toString();
                        
                        // Update the bit display
                        updateBitDisplay();
                        
                        // Update the calculation text
                        updateCalculationText();
                        
                        // Update hex and binary display
                        updateDataDisplay();
                    }
                }
                
                function updateBitDisplay() {
                    // Check all cells in the bit indices grid
                    for (let i = 0; i < bitIndicesGrid.children.length; i++) {
                        let cell = bitIndicesGrid.children[i];
                        
                        // Skip non-data cells (headers)
                        if (!cell.isDataCell) {
                            continue;
                        }
                        
                        // Check if this bit is part of the signal
                        let isPartOfSignal = dbcParser.isBitPartOfSignal(bitsSection.signalName, cell.byteIdx, cell.bitIdx);
                        
                        // Update cell properties
                        cell.isPartOfSignal = isPartOfSignal;
                        
                        if (isPartOfSignal) {
                            // Get the bit value from the C++ backend
                            let bitValue = dbcParser.getBit(bitsSection.signalName, cell.byteIdx, cell.bitIdx);
                            cell.bitValue = bitValue;
                            
                            // Update visual appearance based on bit value
                            cell.color = bitValue ? "#81C784" : "#E8F5E9";
                        } else {
                            // Not part of the signal, use default styling
                            cell.color = "#f5f5f5";
                        }
                    }
                }
            }
        }
        
        // Active Transmissions Tab Content
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#f9f9f9"
            visible: tabBar.currentIndex === 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15
                
                // Header
                Rectangle {
                    Layout.fillWidth: true
                    height: 60
                    color: "white"
                    radius: 8
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        
                        Text {
                            text: "Active Transmissions"
                            font.pixelSize: 20
                            font.bold: true
                            color: "#2E7D32"
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Button {
                            text: "Save Config"
                            enabled: dbcParser.activeTransmissions.length > 0
                            
                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            background: Rectangle {
                                color: parent.enabled ? (parent.pressed ? "#388E3C" : (parent.hovered ? "#43A047" : "#4CAF50")) : "#BDBDBD"
                                radius: 4
                            }
                            
                            onClicked: {
                                saveConfigDialog.open()
                            }
                        }
                        
                        Button {
                            text: "Load Config"
                            
                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            background: Rectangle {
                                color: parent.pressed ? "#1976D2" : (parent.hovered ? "#1E88E5" : "#2196F3")
                                radius: 4
                            }
                            
                            onClicked: {
                                loadConfigDialog.open()
                            }
                        }
                        

                        
                        Button {
                            text: "Kill All"
                            enabled: dbcParser.activeTransmissions.length > 0
                            
                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            background: Rectangle {
                                color: parent.enabled ? (parent.pressed ? "#C62828" : (parent.hovered ? "#D32F2F" : "#F44336")) : "#BDBDBD"
                                radius: 4
                            }
                            
                            onClicked: {
                                if (dbcParser.killAllTransmissions()) {
                                    showStatusMessage("All transmissions killed successfully", false)
                                } else {
                                    showStatusMessage("Failed to kill all transmissions", true)
                                }
                            }
                        }
                    }
                }
                
                // Transmissions Table
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "white"
                    radius: 8
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 10
                        
                        // Table Header
                        Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            color: "#F5F5F5"
                            radius: 4
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 15
                                anchors.rightMargin: 15
                                spacing: 25
                                
                                Text {
                                    Layout.preferredWidth: 100
                                    text: "Message ID"
                                    font.bold: true
                                    color: "#424242"
                                }
                                
                                Text {
                                    Layout.preferredWidth: 180
                                    text: "Message Name"
                                    font.bold: true
                                    color: "#424242"
                                }
                                
                                Text {
                                    Layout.preferredWidth: 120
                                    text: "Interval (ms)"
                                    font.bold: true
                                    color: "#424242"
                                }
                                
                                Text {
                                    Layout.preferredWidth: 100
                                    text: "Status"
                                    font.bold: true
                                    color: "#424242"
                                }
                                
                                Text {
                                    Layout.preferredWidth: 140
                                    text: "Started At"
                                    font.bold: true
                                    color: "#424242"
                                }
                                
                                Text {
                                    Layout.fillWidth: true
                                    text: "Actions"
                                    font.bold: true
                                    color: "#424242"
                                }
                            }
                        }
                        
                        // Transmissions List
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            
                            ListView {
                                id: transmissionsListView
                                model: dbcParser.activeTransmissions
                                
                                delegate: Rectangle {
                                    width: transmissionsListView.width
                                    height: 50
                                    color: index % 2 === 0 ? "white" : "#FAFAFA"
                                    
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: 1
                                        color: "#E0E0E0"
                                    }
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 15
                                        anchors.rightMargin: 15
                                        spacing: 25
                                        
                                        Text {
                                            Layout.preferredWidth: 100
                                            text: "0x" + modelData.messageId.toString(16).toUpperCase()
                                            color: "#424242"
                                        }
                                        
                                        Text {
                                            Layout.preferredWidth: 180
                                            text: modelData.messageName
                                            color: "#424242"
                                            elide: Text.ElideRight
                                        }
                                        
                                        Text {
                                            Layout.preferredWidth: 120
                                            text: modelData.interval.toString()
                                            color: "#424242"
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 100
                                            Layout.preferredHeight: 24
                                            color: modelData.status === "Active" ? "#C8E6C9" : 
                                                   modelData.status === "Paused" ? "#FFE0B2" : 
                                                   modelData.status === "Stopping" ? "#FFF3E0" : "#FFCDD2"
                                            radius: 12
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.status
                                                color: modelData.status === "Active" ? "#2E7D32" : 
                                                       modelData.status === "Paused" ? "#F57C00" : 
                                                       modelData.status === "Stopping" ? "#FF6F00" : "#C62828"
                                                font.pixelSize: 12
                                                font.bold: true
                                            }
                                        }
                                        
                                        Text {
                                            Layout.preferredWidth: 140
                                            text: Qt.formatDateTime(modelData.startedAt, "hh:mm:ss")
                                            color: "#757575"
                                            font.pixelSize: 12
                                        }
                                        
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 5
                                            
                                            Button {
                                                Layout.preferredWidth: 60
                                                Layout.preferredHeight: 36
                                                text: modelData.status === "Paused" ? "Resume" : "Pause"
                                                enabled: modelData.status !== "Stopped" && modelData.status !== "Stopping"
                                                
                                                contentItem: Text {
                                                    text: parent.text
                                                    color: "white"
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                    font.pixelSize: 11
                                                }
                                                
                                                background: Rectangle {
                                                    color: parent.enabled ? (parent.pressed ? "#F57C00" : (parent.hovered ? "#FB8C00" : "#FF9800")) : "#BDBDBD"
                                                    radius: 4
                                                }
                                                
                                                onClicked: {
                                                    if (modelData.status === "Paused") {
                                                        dbcParser.resumeTransmission(modelData.messageName)
                                                    } else {
                                                        dbcParser.pauseTransmission(modelData.messageName)
                                                    }
                                                }
                                            }
                                            
                                            Button {
                                                Layout.preferredWidth: 50
                                                Layout.preferredHeight: 36
                                                text: modelData.status === "Stopping" ? "..." : "Stop"
                                                enabled: modelData.status !== "Stopped" && modelData.status !== "Stopping"
                                                
                                                contentItem: Text {
                                                    text: parent.text
                                                    color: "white"
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                    font.pixelSize: 11
                                                }
                                                
                                                background: Rectangle {
                                                    color: parent.enabled ? (parent.pressed ? "#D32F2F" : (parent.hovered ? "#E53935" : "#F44336")) : "#BDBDBD"
                                                    radius: 4
                                                }
                                                
                                                onClicked: {
                                                    dbcParser.stopTransmission(modelData.messageName)
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // Empty state
                                Text {
                                    anchors.centerIn: parent
                                    text: "No active transmissions"
                                    color: "#757575"
                                    font.pixelSize: 16
                                    visible: transmissionsListView.count === 0
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // TCP Client Tab
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: tabBar.currentIndex === 2
        color: "#FAFAFA"
        
        TcpClientTab {
            id: tcpClientTab
            anchors.fill: parent
        }
    }
    
    // Save Configuration Dialog
    FileDialog {
        id: saveConfigDialog
        title: "Save Active Transmissions Configuration"
        fileMode: FileDialog.SaveFile
        nameFilters: ["JSON Files (*.json)"]
        onAccepted: {
            dbcParser.saveActiveTransmissionsConfig(selectedFile)
        }
    }
    
    // Load Configuration Dialog
    FileDialog {
        id: loadConfigDialog
        title: "Load Active Transmissions Configuration"
        fileMode: FileDialog.OpenFile
        nameFilters: ["JSON Files (*.json)"]
        onAccepted: {
            console.log("Loading config file:", selectedFile)
            var success = dbcParser.loadActiveTransmissionsConfig(selectedFile)
            if (success) {
                console.log("Configuration loaded successfully")
                showStatusMessage("Configuration loaded successfully!", false)
            } else {
                console.log("Failed to load configuration")
                showStatusMessage("Failed to load configuration file!", true)
            }
        }
    }
    
    Dialog {
    id: diffDialog
    modal: true
    title: "Compare and Download Updated DBC"
    width: 1400
    height: 800

    property var originalContent: []
    property var modifiedContent: []
    property var diffLines: []

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // Header with file info
        Rectangle {
            Layout.fillWidth: true
            height: 50
            color: "#F6F8FA"
            border.color: "#D0D7DE"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 15

                Rectangle {
                    width: 6
                    height: 25
                    color: "#0969DA"
                    radius: 3
                }

                Text {
                    text: "File Comparison"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#24292F"
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 20
                    color: "#D0D7DE"
                }

                Text {
                    id: changesSummary
                    text: "Only showing changed sections"
                    font.pixelSize: 12
                    color: "#656D76"
                }

                Item { Layout.fillWidth: true }

                // Legend
                RowLayout {
                    spacing: 15

                    RowLayout {
                        spacing: 5
                        Rectangle {
                            width: 12
                            height: 12
                            color: "#FFC107"
                            radius: 2
                        }
                        Text {
                            text: "Original"
                            font.pixelSize: 11
                            color: "#656D76"
                        }
                    }

                    RowLayout {
                        spacing: 5
                        Rectangle {
                            width: 12
                            height: 12
                            color: "#2DA44E"
                            radius: 2
                        }
                        Text {
                            text: "Modified"
                            font.pixelSize: 11
                            color: "#656D76"
                        }
                    }
                }
            }
        }

        // Split view for comparison
        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal

            // Original file panel
            Rectangle {
                SplitView.preferredWidth: parent.width * 0.5
                SplitView.minimumWidth: 350
                color: "white"
                border.color: "#D0D7DE"
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Header for original
                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        color: "#F6F8FA"
                        border.color: "#D0D7DE"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 15
                            anchors.rightMargin: 15

                            Rectangle {
                                width: 4
                                height: 20
                                color: "#656D76"
                                radius: 2
                            }

                            Text {
                                text: "Original DBC File"
                                font.pixelSize: 13
                                font.bold: true
                                color: "#24292F"
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        ListView {
                            id: originalView
                            model: diffDialog.originalContent
                            spacing: 0

                            delegate: Rectangle {
                                width: Math.max(originalView.width, originalRowLayout.implicitWidth + 20)
                                height: Math.max(22, originalText.contentHeight + 4)
                                color: modelData.changed ? "#FFF8C5" : (index % 2 === 0 ? "#FAFBFC" : "white")

                                RowLayout {
                                    id: originalRowLayout
                                    anchors.fill: parent
                                    spacing: 0

                                    // Line number
                                    Rectangle {
                                        Layout.preferredWidth: 50
                                        Layout.fillHeight: true
                                        color: "#F6F8FA"
                                        border.color: "#D0D7DE"
                                        border.width: modelData.changed ? 0 : 0

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.lineNumber || (index + 1)
                                            font.family: "Monaco"
                                            font.pixelSize: 10
                                            color: "#656D76"
                                        }
                                    }

                                    // Change indicator
                                    Rectangle {
                                        Layout.preferredWidth: 4
                                        Layout.fillHeight: true
                                        color: modelData.changed ? "#FFC107" : "transparent"
                                    }

                                    // Content
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: "transparent"

                                        Text {
                                            id: originalText
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            text: modelData.text
                                            font.family: "Monaco"
                                            font.pixelSize: 11
                                            color: "#24292F"
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                }

                                // Bottom border for changed lines
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: modelData.changed ? 1 : 0
                                    color: "#FFC107"
                                    opacity: 0.3
                                }
                            }
                        }
                    }
                }
            }

            // Modified file panel
            Rectangle {
                SplitView.preferredWidth: parent.width * 0.5
                SplitView.minimumWidth: 350
                color: "white"
                border.color: "#D0D7DE"
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Header for modified
                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        color: "#F6F8FA"
                        border.color: "#D0D7DE"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 15
                            anchors.rightMargin: 15

                            Rectangle {
                                width: 4
                                height: 20
                                color: "#2DA44E"
                                radius: 2
                            }

                            Text {
                                text: "Modified DBC File"
                                font.pixelSize: 13
                                font.bold: true
                                color: "#24292F"
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        ListView {
                            id: modifiedView
                            model: diffDialog.modifiedContent
                            spacing: 0

                            delegate: Rectangle {
                                width: Math.max(modifiedView.width, modifiedRowLayout.implicitWidth + 20)
                                height: Math.max(22, modifiedText.contentHeight + 4)
                                color: modelData.changed ? "#DCFCE7" : (index % 2 === 0 ? "#FAFBFC" : "white")

                                RowLayout {
                                    id: modifiedRowLayout
                                    anchors.fill: parent
                                    spacing: 0

                                    // Line number
                                    Rectangle {
                                        Layout.preferredWidth: 50
                                        Layout.fillHeight: true
                                        color: "#F6F8FA"
                                        border.color: "#D0D7DE"
                                        border.width: 0

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.lineNumber || (index + 1)
                                            font.family: "Monaco"
                                            font.pixelSize: 10
                                            color: "#656D76"
                                        }
                                    }

                                    // Change indicator
                                    Rectangle {
                                        Layout.preferredWidth: 4
                                        Layout.fillHeight: true
                                        color: modelData.changed ? "#2DA44E" : "transparent"
                                    }

                                    // Content
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: "transparent"

                                        Text {
                                            id: modifiedText
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            text: modelData.text
                                            font.family: "Monaco"
                                            font.pixelSize: 11
                                            color: "#24292F"
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                }

                                // Bottom border for changed lines
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: modelData.changed ? 1 : 0
                                    color: "#2DA44E"
                                    opacity: 0.3
                                }
                            }
                        }
                    }
                }
            }
        }

        // Action buttons
        Rectangle {
            Layout.fillWidth: true
            height: 60
            color: "#F6F8FA"
            border.color: "#D0D7DE"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 12

                Item { Layout.fillWidth: true }

                Button {
                    text: "Download Updated DBC"
                    Layout.preferredWidth: 180
                    Layout.preferredHeight: 40

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    background: Rectangle {
                        color: parent.pressed ? "#0A69DA" : (parent.hovered ? "#1F6FEB" : "#0969DA")
                        radius: 6
                        border.color: "transparent"

                        // Subtle shadow
                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: 1
                            color: "#000000"
                            opacity: 0.1
                            radius: 6
                            z: -1
                        }

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }
                    }

                    onClicked: {
                        fileSaveDialog.open()
                    }
                }

                Button {
                    text: "Cancel"
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 40

                    contentItem: Text {
                        text: parent.text
                        color: "#24292F"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 13
                    }

                    background: Rectangle {
                        color: parent.pressed ? "#EAEEF2" : (parent.hovered ? "#F3F4F6" : "#F6F8FA")
                        radius: 6
                        border.color: "#D0D7DE"
                        border.width: 1

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }
                    }

                    onClicked: {
                        diffDialog.close()
                    }
                }
            }
        }
    }

    // Function to populate the dialog with diff data
    function showDiff() {
        var diffData = dbcParser.getStructuredDiff()
        originalContent = diffData.original
        modifiedContent = diffData.modified
        
        // Update summary
        var originalChanges = 0
        var modifiedChanges = 0
        
        for (var i = 0; i < originalContent.length; i++) {
            if (originalContent[i].changed) originalChanges++
        }
        
        for (var j = 0; j < modifiedContent.length; j++) {
            if (modifiedContent[j].changed) modifiedChanges++
        }
        
        if (originalChanges === 0 && modifiedChanges === 0) {
            changesSummary.text = "No changes detected - file is identical to original"
            changesSummary.color = "#656D76"
        } else {
            changesSummary.text = originalChanges + " lines in original, " + modifiedChanges + " lines modified"
            changesSummary.color = "#0969DA"
        }
        
        open()
    }
}

    FileDialog {
    id: fileSaveDialog
    title: "Save Modified DBC File"
    fileMode: FileDialog.SaveFile
    nameFilters: ["DBC Files (*.dbc)"]
    defaultSuffix: "dbc"

    onAccepted: {
        if (dbcParser.saveModifiedDbcToFile(selectedFile)) {
            diffDialog.close()
        } else {
            console.log("Failed to save file")
        }
    }
}
    // Dialog instances
        AddMessageDialog {
            id: addMessageDialog
        }

        AddSignalDialog {
            id: addSignalDialog
        }
        // Send Message Dialog
        SendMessageDialog {
            id: sendMessageDialog
            window: window // Pass reference to main window
        }


        // Confirmation dialog for removing signals
        Dialog {
            id: removeSignalConfirmDialog
            title: "Confirm Deletion"
            property string messageName: ""
            property string signalName: ""
            modal: true
            anchors.centerIn: parent
            width: 400

            contentItem: ColumnLayout {
                spacing: 20

                Label {
                    text: "Are you sure you want to delete signal '" + removeSignalConfirmDialog.signalName + "'?"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            standardButtons: Dialog.Yes | Dialog.No

            onAccepted: {
                dbcParser.removeSignal(messageName, signalName)
            }
        }
        // Confirmation dialog for removing messages
        Dialog {
            id: removeMessageConfirmDialog
            title: "Confirm Deletion"
            property string messageName: ""
            modal: true
            anchors.centerIn: parent
            width: 420

            background: Rectangle {
                color: "white"
                radius: 8
                border.color: "#E0E0E0"
                border.width: 1
            }

            header: Rectangle {
                height: 50
                color: "#F5F5F5"
                radius: 8

                Text {
                    anchors.centerIn: parent
                    text: removeMessageConfirmDialog.title
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: "#424242"
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: "#E0E0E0"
                }
            }

            contentItem: ColumnLayout {
                spacing: 20

                Item { height: 10 }

                Label {
                    text: "Are you sure you want to delete message '" + removeMessageConfirmDialog.messageName + "' and all its signals?"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    font.pixelSize: 14
                    color: "#616161"
                }

                Item { height: 10 }
            }

            footer: DialogButtonBox {
                padding: 20

                background: Rectangle {
                    color: "#FAFAFA"
                    radius: 8
                }

                Button {
                    text: "Cancel"
                    DialogButtonBox.buttonRole: DialogButtonBox.RejectRole

                    background: Rectangle {
                        color: parent.pressed ? "#E0E0E0" :
                               (parent.hovered ? "#F5F5F5" : "transparent")
                        border.color: "#BDBDBD"
                        border.width: 1
                        radius: 4
                    }
                }

                Button {
                    text: "Delete"
                    DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: parent.pressed ? "#D32F2F" :
                               (parent.hovered ? "#E53935" : "#F44336")
                        radius: 4
                    }
                }
            }
        }
    }  // End of main ColumnLayout

    // =============================================
    // CENTRALIZED NOTIFICATION SYSTEM
    // =============================================
    
    // Notification Component
    Component {
        id: notificationComponent
        
        Rectangle {
            id: notification
            width: 400
            height: 90 // Slightly taller for better content fit
            radius: 8
            border.width: 2
            
            property string message: ""
            property string type: "info" // "error", "warning", "success", "info"
            property alias autoClose: autoCloseTimer.running
            
            // Drop shadow effect
            Rectangle {
                id: shadow
                anchors.fill: parent
                anchors.topMargin: 2
                anchors.leftMargin: 2
                radius: parent.radius
                color: "#20000000"
                z: -1
            }
            
            // Colors based on type
            color: {
                switch(type) {
                    case "error": return "#FFEBEE"
                    case "warning": return "#FFF8E1" 
                    case "success": return "#E8F5E8"
                    case "info": return "#E3F2FD"
                    default: return "#F5F5F5"
                }
            }
            
            border.color: {
                switch(type) {
                    case "error": return "#F44336"
                    case "warning": return "#FF9800"
                    case "success": return "#4CAF50"
                    case "info": return "#2196F3"
                    default: return "#BDBDBD"
                }
            }
            
            // Slide in animation
            NumberAnimation on x {
                id: slideInAnimation
                from: 450
                to: 0
                duration: 300
                easing.type: Easing.OutCubic
                running: true
            }
            
            // Slide out animation
            NumberAnimation {
                id: slideOutAnimation
                target: notification
                property: "x"
                to: 450
                duration: 300
                easing.type: Easing.InCubic
                onFinished: notification.destroy()
            }
            
            // Auto-close timer (5 seconds for errors, 3 seconds for others)
            Timer {
                id: autoCloseTimer
                interval: notification.type === "error" ? 5000 : 3000
                repeat: false
                onTriggered: notification.close()
            }
            
            // Close button - placed first so it's on top
            Button {
                id: closeButton
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                width: 24
                height: 24
                z: 10 // Ensure it's on top
                
                contentItem: Text {
                    text: "×"
                    color: "#757575"
                    font.pixelSize: 18
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    anchors.centerIn: parent
                }
                
                background: Rectangle {
                    color: parent.hovered ? "#E0E0E0" : "transparent"
                    radius: 12
                    border.color: parent.hovered ? "#BDBDBD" : "transparent"
                    border.width: 1
                }
                
                onClicked: {
                    console.log("Close button clicked!")
                    notification.close()
                }
                
                // Make sure the button is clickable
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        console.log("MouseArea clicked!")
                        notification.close()
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 15
                anchors.rightMargin: 40 // Leave space for close button
                spacing: 15
                
                // Icon
                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignVCenter
                    radius: 20
                    
                    color: {
                        switch(notification.type) {
                            case "error": return "#F44336"
                            case "warning": return "#FF9800"
                            case "success": return "#4CAF50"
                            case "info": return "#2196F3"
                            default: return "#BDBDBD"
                        }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        color: "white"
                        font.pixelSize: 18
                        font.bold: true
                        text: {
                            switch(notification.type) {
                                case "error": return "✗"
                                case "warning": return "⚠"
                                case "success": return "✓"
                                case "info": return "ℹ"
                                default: return "●"
                            }
                        }
                    }
                }
                
                // Message Content
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4
                    
                    Text {
                        Layout.fillWidth: true
                        text: {
                            switch(notification.type) {
                                case "error": return "Error"
                                case "warning": return "Warning"
                                case "success": return "Success"
                                case "info": return "Info"
                                default: return "Notification"
                            }
                        }
                        color: {
                            switch(notification.type) {
                                case "error": return "#D32F2F"
                                case "warning": return "#F57C00"
                                case "success": return "#388E3C"
                                case "info": return "#1976D2"
                                default: return "#424242"
                            }
                        }
                        font.pixelSize: 16
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }
                    
                    Text {
                        Layout.fillWidth: true
                        text: notification.message
                        color: "#424242"
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
            }
            
            // Close function
            function close() {
                autoCloseTimer.stop()
                slideOutAnimation.start()
            }
            
            Component.onCompleted: {
                autoCloseTimer.start()
            }
        }
    }
    
    // Notification Container - positioned at top-right of screen
    Rectangle {
        id: notificationContainer
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 70 // Below the header
        anchors.rightMargin: 20
        width: 420
        height: childrenRect.height
        color: "transparent"
        z: 1000 // High z-index to appear on top
        
        Column {
            id: notificationColumn
            width: parent.width
            spacing: 10
        }
    }
    
    // Set up the connection between TCP Client and DbcParser
    Component.onCompleted: {
        if (tcpClientTab && tcpClientTab.tcpClient) {
            dbcParser.setTcpClient(tcpClientTab.tcpClient)
            console.log("Connected DbcParser to TCP Client")
            
            // Force update the connection status
            dbcParser.updateConnectionStatus()
        }
    }
    
    // Additional connection to monitor TCP client status
    Connections {
        target: tcpClientTab ? tcpClientTab.tcpClient : null
        
        function onConnectionStatusChanged() {
            console.log("Main: TCP Client connection status changed")
            // Force update the DbcParser connection status
            if (dbcParser) {
                dbcParser.updateConnectionStatus()
            }
            // Update the header indicator
            connectionStatusIndicator.color = connectionStatusIndicator.getConnectionStatus() ? "#2E7D32" : "#D32F2F"
        }
    }
    
    // Timer to periodically update connection status
    Timer {
        id: connectionStatusTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (connectionStatusIndicator) {
                connectionStatusIndicator.color = connectionStatusIndicator.getConnectionStatus() ? "#2E7D32" : "#D32F2F"
            }
        }
    }
}
