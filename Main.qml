import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Controls.Material

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
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 30
                    color: dbcParser.isConnectedToServer ? "#2E7D32" : "#D32F2F"
                    radius: 15
                    border.color: "white"
                    border.width: 1
                    
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 5
                        
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: "white"
                            
                            SequentialAnimation on opacity {
                                running: dbcParser.isConnectedToServer
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 800 }
                                NumberAnimation { to: 1.0; duration: 800 }
                            }
                        }
                        
                        Text {
                            text: dbcParser.isConnectedToServer ? "Connected" : "Disconnected"
                            color: "white"
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (!dbcParser.isConnectedToServer) {
                                dbcParser.connectToServer("127.0.0.1", "8080")
                            }
                        }
                    }
                    
                    ToolTip {
                        visible: parent.hovered
                        text: dbcParser.isConnectedToServer ? 
                              "Connected to CAN receiver (127.0.0.1:8080)" : 
                              "Click to connect to CAN receiver"
                        delay: 500
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
                        diffDialog.diffLines = dbcParser.getDbcDiffLines()
                        diffDialog.open()
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
        
        // Main content area
        SplitView {
            id: mainSplitView
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Vertical
            
            // Top section with messages and signals
            SplitView {
                id: topSplitView
                SplitView.preferredHeight: parent.height * 0.7
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
                            
                            delegate: Rectangle {
                                width: parent.width
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

                                // Click handler for the entire delegate (excluding the send button)
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.rightMargin: 70 // Don't overlap with the send button
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
                                    
                                    delegate: Rectangle {
                                        width: signalTableRow.width
                                        height: 45
                                        color: index % 2 == 0 ? "#F5F5F5" : "white"
                                        
                                        // Signal row content
                                        Row {
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
                                                        Layout.preferredWidth: 50
                                                        Layout.preferredHeight: 28
                                                        text: "Bits"

                                                        contentItem: Text {
                                                            text: parent.text
                                                            color: parent.enabled ? "#4CAF50" : "#CCCCCC"
                                                            horizontalAlignment: Text.AlignHCenter
                                                            verticalAlignment: Text.AlignVCenter
                                                            font.pixelSize: 11
                                                            font.weight: Font.Medium
                                                        }

                                                        background: Rectangle {
                                                            color: parent.pressed ? "#E8F5E9" :
                                                                   (parent.hovered ? "#F1F8E9" : "transparent")
                                                            border.color: parent.enabled ? "#4CAF50" : "#CCCCCC"
                                                            border.width: 1
                                                            radius: 4

                                                            Behavior on color {
                                                                ColorAnimation { duration: 100 }
                                                            }
                                                        }

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
                                        
                                        // Highlight selected item
                                        Rectangle {
                                            anchors.fill: parent
                                            color: signalListView.currentIndex === index ? "#E8F5E9" : "transparent"
                                            opacity: 0.5
                                            z: -1
                                        }
                                        
                                        MouseArea {
                                            anchors.fill: parent
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
                SplitView.preferredHeight: parent.height * 0.3
                SplitView.minimumHeight: 200
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
                            Layout.preferredWidth: parent.width * 0.5
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
                                        spacing: 1
                                        
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
                                        font.family: "Monospace"
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
                                        font.family: "Monospace"
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
                                            font.family: "Monospace"
                                            font.pixelSize: 14
                                        }
                                        
                                        Text {
                                            id: physicalValueText
                                            text: "Physical value = 1.0 * 0 + 0 = 0"
                                            font.family: "Monospace"
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
                    // Get the frame data as hex and binary
                    var hexData = dbcParser.getFrameDataHex(bitsSection.signalName, bitsSection.rawValue);
                    var binData = dbcParser.getFrameDataBin(bitsSection.signalName, bitsSection.rawValue);
                    
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
    }
    Dialog {
    id: diffDialog
    modal: true
    title: "Compare and Download Updated DBC"
    standardButtons: Dialog.Cancel
    width: 1200
    height: 700

    property var diffLines: []

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 10

        ListView {
            id: diffView
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: diffDialog.diffLines

            delegate: Rectangle {
                width: parent.width
                height: 24
                color: modelData.startsWith("+") ? "#E8F5E9" :
                       modelData.startsWith("-") ? "#FFEBEE" : "white"

                Row {
                    anchors.fill: parent
                    spacing: 5

                    Text {
                        text: modelData
                        color: modelData.startsWith("+") ? "#2E7D32" :
                               modelData.startsWith("-") ? "#C62828" : "#424242"
                        font.family: "Monospace"
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Button {
            text: "Download Updated DBC"
            Layout.alignment: Qt.AlignRight
            onClicked: {
                fileSaveDialog.open()
            }
        }
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

        // Similar styling for removeSignalConfirmDialog...
}
