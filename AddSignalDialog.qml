import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

Dialog {
    id: addSignalDialog
    title: "Add New Signal"
    modal: true
    anchors.centerIn: parent
    width: 650  // Optimal width for clean layout
    height: 700  // Reduced height since we simplified the UI
    padding: 0

    property string currentMessageName: ""
    
    // Signal emitted when a signal is successfully added
    signal signalAdded(string signalName, string messageName)
    
    // Error popup dialog
    Dialog {
        id: errorPopup
        title: "Signal Addition Error"
        modal: true
        anchors.centerIn: parent
        width: 400
        height: 200
        
        property alias errorText: errorMessage.text
        
        background: Rectangle {
            color: "#FFFFFF"
            radius: 12
            border.color: "#D32F2F"
            border.width: 2
        }
        
        header: Rectangle {
            height: 60
            color: "#D32F2F"
            radius: 12
            
            Text {
                anchors.centerIn: parent
                text: "Error"
                font.pixelSize: 18
                font.weight: Font.Bold
                color: "white"
            }
        }
        
        contentItem: Rectangle {
            color: "transparent"
            
            Text {
                id: errorMessage
                anchors.centerIn: parent
                width: parent.width - 40
                wrapMode: Text.WordWrap
                font.pixelSize: 14
                font.weight: Font.Medium
                color: "#D32F2F"
                horizontalAlignment: Text.AlignHCenter
            }
        }
        
        footer: Rectangle {
            color: "#F8F9FA"
            height: 60
            radius: 12
            
            Button {
                anchors.centerIn: parent
                text: "OK"
                width: 100
                height: 40
                
                background: Rectangle {
                    color: parent.hovered ? "#C62828" : "#D32F2F"
                    radius: 8
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: errorPopup.close()
            }
        }
        
        onClosed: {
            // Don't automatically reset start bit to avoid infinite loops
            // User can manually adjust or try again
            console.log("AddSignalDialog: Error popup closed")
        }
    }
    


    background: Rectangle {
        color: "#FFFFFF"
        radius: 12
        border.color: "#E0E0E0"
        border.width: 1
    }

    header: Rectangle {
        height: 80
        color: "#4CAF50"
        radius: 12

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4

            Text {
                text: "Add New Signal"
                font.pixelSize: 22
                font.weight: Font.Bold
                color: "white"
                Layout.alignment: Qt.AlignHCenter
            }
            
            Text {
                text: currentMessageName ? "to message: " + currentMessageName : ""
                font.pixelSize: 14
                font.weight: Font.Medium
                color: "#E8F5E9"
                Layout.alignment: Qt.AlignHCenter
                visible: currentMessageName !== ""
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 2
            color: "#388E3C"
        }
    }

    contentItem: ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.Never
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        contentWidth: availableWidth
        contentHeight: contentLayout.implicitHeight + 50  // Add extra space at bottom
        
        ColumnLayout {
            id: contentLayout
            width: Math.min(500, parent.width)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 30
            
            // Title section
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 4
                color: "#4CAF50"
                radius: 2
                Layout.topMargin: 10
            }
            
            // Signal Name
            ColumnLayout {
                spacing: 8
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.topMargin: 15

                Text {
                    text: "Signal Name:"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: "#2E7D32"
                    Layout.alignment: Qt.AlignLeft
                    Layout.leftMargin: 10
                }

                TextField {
                    id: signalNameField
                    Layout.preferredWidth: 380
                    Layout.preferredHeight: 50
                    Layout.alignment: Qt.AlignHCenter
                    font.pixelSize: 16
                    selectByMouse: true
                    padding: 16
                    topPadding: 14
                    bottomPadding: 14
                    leftPadding: 20
                    rightPadding: 20

                    background: Rectangle {
                        color: parent.enabled ? "#FFFFFF" : "#F5F5F5"
                        radius: 8
                        border.color: {
                            if (parent.activeFocus) return "#4CAF50"
                            if (parent.text.length === 0) return "#9E9E9E"
                            return "#CCCCCC"
                        }
                        border.width: parent.activeFocus ? 2 : 1.5
                        
                        // Add a subtle shadow effect
                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: 2
                            color: "transparent"
                            radius: parent.radius
                            border.color: "#00000010"
                            border.width: 1
                            z: -1
                        }
                    }
                    
                    // Custom validation indicator
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6
                        height: 6
                        radius: 3
                        color: parent.text.length > 0 ? "#4CAF50" : "#9E9E9E"
                        visible: parent.text.length > 0 || parent.activeFocus
                    }
                    
                    // Clear errors when user types
                    onTextChanged: {
                        if (text.trim().length > 0) {
                            clearError()
                        }
                    }
                    
                    // Force sync when focus changes
                    onActiveFocusChanged: {
                        if (!activeFocus) {
                            console.log("AddSignalDialog: Signal name field lost focus, current text:", text)
                        }
                    }
                }
            }

                // Start Bit and Length - Centered grid
                GridLayout {
                    columns: 2
                    columnSpacing: 40
                    rowSpacing: 20
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    Layout.topMargin: 10

                    // Start Bit
                    ColumnLayout {
                        spacing: 10
                        Layout.preferredWidth: 250  // Fixed width for consistent sizing
                        Layout.alignment: Qt.AlignHCenter

                        RowLayout {
                            spacing: 8
                            Layout.alignment: Qt.AlignHCenter
                            
                            Text {
                                text: "Start Bit:"
                                font.pixelSize: 15
                                font.weight: Font.Medium
                                color: "#424242"
                            }
                            
                            Button {
                                text: "Auto"
                                Layout.preferredWidth: 60
                                Layout.preferredHeight: 32
                                font.pixelSize: 12
                                
                                background: Rectangle {
                                    color: {
                                        if (parent.pressed) return "#388E3C"
                                        if (parent.hovered) return "#66BB6A"
                                        return "#4CAF50"
                                    }
                                    radius: 8
                                    border.color: "#2E7D32"
                                    border.width: 1
                                    
                                    // Subtle shadow effect
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.topMargin: 2
                                        color: "transparent"
                                        radius: parent.radius
                                        border.color: "#00000015"
                                        border.width: 1
                                        z: -1
                                    }
                                }
                                
                                contentItem: Text {
                                    text: parent.text
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: "white"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: {
                                    console.log("AddSignalDialog: User clicked Auto button - current length:", lengthSpinBox.value)
                                    setNextAvailableStartBit()
                                    console.log("AddSignalDialog: After Auto button - start bit set to:", startBitSpinBox.value)
                                }
                                
                                ToolTip.visible: hovered
                                ToolTip.text: "Auto-assign start bit to next available position"
                                ToolTip.delay: 500
                            }
                        }

                        SpinBox {
                            id: startBitSpinBox
                            Layout.preferredWidth: 200  // Fixed width
                            Layout.alignment: Qt.AlignHCenter
                            from: 0
                            to: 63
                            value: 0
                            editable: true
                            
                            // Update bit visualization when start bit changes
                            onValueChanged: {
                                if (addSignalDialog.visible) {
                                    console.log("AddSignalDialog: Start bit changed to:", value)
                                    // Clear any existing errors when user manually changes start bit
                                    clearError()
                                    // Force refresh of bit visualization
                                    updateBitVisualization()
                                }
                            }

                            contentItem: TextField {
                                text: parent.value
                                font.pixelSize: 16
                                color: "#424242"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                selectByMouse: true
                                padding: 12

                                background: Rectangle {
                                    color: "transparent"
                                    border.width: 0
                                }
                            }

                            background: Rectangle {
                                color: "#FAFAFA"
                                radius: 8
                                border.color: parent.activeFocus ? "#4CAF50" : "#CCCCCC"
                                border.width: parent.activeFocus ? 2 : 1.5
                                implicitHeight: 50  // Taller
                                implicitWidth: 200  // Wider
                            }

                            up.indicator: Rectangle {
                                x: parent.width - width - 8
                                y: 8
                                width: 35
                                height: parent.height / 2 - 8
                                color: parent.up.pressed ? "#E8F5E9" : "#F5F5F5"
                                radius: 4

                                Text {
                                    text: "▲"
                                    font.pixelSize: 14
                                    color: "#4CAF50"
                                    anchors.centerIn: parent
                                }
                            }

                            down.indicator: Rectangle {
                                x: parent.width - width - 8
                                y: parent.height / 2
                                width: 35
                                height: parent.height / 2 - 8
                                color: parent.down.pressed ? "#E8F5E9" : "#F5F5F5"
                                radius: 4

                                Text {
                                    text: "▼"
                                    font.pixelSize: 14
                                    color: "#4CAF50"
                                    anchors.centerIn: parent
                                }
                            }
                        }
                    }

                    // Length
                    ColumnLayout {
                        spacing: 10
                        Layout.preferredWidth: 250
                        Layout.alignment: Qt.AlignHCenter

                        Text {
                            text: "Length (bits):"
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            color: "#424242"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        SpinBox {
                            id: lengthSpinBox
                            Layout.preferredWidth: 200
                            Layout.alignment: Qt.AlignHCenter
                            from: 1
                            to: 64
                            value: 8
                            editable: true
                            
                            // Update start bit when length changes
                            onValueChanged: {
                                if (addSignalDialog.visible) {
                                    console.log("AddSignalDialog: Length changed to:", value)
                                    // Clear any existing errors when user changes length
                                    clearError()
                                    // Only auto-adjust start bit if current start bit + length would exceed 64
                                    if (startBitSpinBox.value + value > 64) {
                                        console.log("AddSignalDialog: Signal would exceed 64 bits, finding new start bit")
                                        setNextAvailableStartBit()
                                    }
                                    updateBitVisualization()
                                }
                            }

                            contentItem: TextField {
                                text: parent.value
                                font.pixelSize: 16
                                color: "#424242"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                selectByMouse: true
                                padding: 12

                                background: Rectangle {
                                    color: "transparent"
                                    border.width: 0
                                }
                            }

                            background: Rectangle {
                                color: "#FAFAFA"
                                radius: 8
                                border.color: parent.activeFocus ? "#4CAF50" : "#CCCCCC"
                                border.width: parent.activeFocus ? 2 : 1.5
                                implicitHeight: 50
                                implicitWidth: 200
                            }

                            up.indicator: Rectangle {
                                x: parent.width - width - 8
                                y: 8
                                width: 35
                                height: parent.height / 2 - 8
                                color: parent.up.pressed ? "#E8F5E9" : "#F5F5F5"
                                radius: 4

                                Text {
                                    text: "▲"
                                    font.pixelSize: 14
                                    color: "#4CAF50"
                                    anchors.centerIn: parent
                                }
                            }

                            down.indicator: Rectangle {
                                x: parent.width - width - 8
                                y: parent.height / 2
                                width: 35
                                height: parent.height / 2 - 8
                                color: parent.down.pressed ? "#E8F5E9" : "#F5F5F5"
                                radius: 4

                                Text {
                                    text: "▼"
                                    font.pixelSize: 14
                                    color: "#4CAF50"
                                    anchors.centerIn: parent
                                }
                            }
                        }
                    }
                }



            // Byte Order - Centered
            ColumnLayout {
                spacing: 12
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.topMargin: 15

                Text {
                    text: "Byte Order:"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: "#2E7D32"
                    Layout.alignment: Qt.AlignHCenter
                }

                ComboBox {
                    id: byteOrderCombo
                    Layout.preferredWidth: 380
                    Layout.alignment: Qt.AlignHCenter
                    model: ["Little Endian (Intel)", "Big Endian (Motorola)"]
                    currentIndex: 0

                    background: Rectangle {
                        color: "#FAFAFA"
                        radius: 8
                        border.color: parent.activeFocus ? "#4CAF50" : "#CCCCCC"
                        border.width: parent.activeFocus ? 2 : 1.5
                        implicitHeight: 50
                    }

                        contentItem: Text {
                            text: parent.displayText
                            color: "#424242"
                            font.pixelSize: 15
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            leftPadding: 20
                            rightPadding: 40
                        }

                        popup: Popup {
                            width: parent.width
                            implicitHeight: Math.min(400, contentItem.implicitHeight + 20)
                            padding: 8

                            contentItem: ListView {
                                clip: true
                                implicitHeight: contentHeight
                                model: parent.parent.model
                                currentIndex: parent.parent.currentIndex

                                delegate: ItemDelegate {
                                    width: parent.width
                                    height: 45
                                    highlighted: parent.parent.currentIndex === index

                                    contentItem: Text {
                                        text: modelData
                                        font.pixelSize: 14
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        color: "#424242"
                                    }

                                    background: Rectangle {
                                        color: highlighted ? "#E8F5E9" : "white"
                                        radius: 4
                                    }
                                }
                            }

                            background: Rectangle {
                                color: "white"
                                radius: 8
                                border.color: "#E0E0E0"
                                border.width: 1
                            }
                        }                indicator: Canvas {
                    x: parent.width - width - 15
                    y: parent.height / 2 - height / 2
                    width: 12
                    height: 8
                    contextType: "2d"

                    onPaint: {
                        var context = getContext("2d");
                        context.reset();
                        context.moveTo(0, 0);
                        context.lineTo(width, 0);
                        context.lineTo(width / 2, height);
                        context.closePath();
                        context.fillStyle = "#666666";
                        context.fill();
                    }
                }
            }
        }

                // Factor and Offset - Centered grid
                GridLayout {
                    columns: 2
                    columnSpacing: 40
                    rowSpacing: 20
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 20

                    ColumnLayout {
                        spacing: 10
                        Layout.preferredWidth: 250
                        Layout.alignment: Qt.AlignHCenter

                        Text {
                            text: "Factor:"
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            color: "#2E7D32"
                            Layout.alignment: Qt.AlignLeft
                            Layout.leftMargin: 25
                        }

                        TextField {
                            id: factorField
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 50
                            Layout.alignment: Qt.AlignHCenter
                            text: "1.0"
                            font.pixelSize: 16
                            selectByMouse: true
                            padding: 16
                            horizontalAlignment: Text.AlignHCenter
                            validator: DoubleValidator { bottom: -999999; top: 999999; decimals: 6 }

                            background: Rectangle {
                                color: "#FFFFFF"
                                radius: 8
                                border.color: parent.activeFocus ? "#4CAF50" : "#CCCCCC"
                                border.width: parent.activeFocus ? 2 : 1.5
                                implicitHeight: 50
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 10
                        Layout.preferredWidth: 250
                        Layout.alignment: Qt.AlignHCenter

                        Text {
                            text: "Offset:"
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            color: "#2E7D32"
                            Layout.alignment: Qt.AlignLeft
                            Layout.leftMargin: 25
                        }

                        TextField {
                            id: offsetField
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 50
                            Layout.alignment: Qt.AlignHCenter
                            text: "0.0"
                            font.pixelSize: 16
                            selectByMouse: true
                            padding: 16
                            horizontalAlignment: Text.AlignHCenter
                            validator: DoubleValidator { bottom: -999999; top: 999999; decimals: 6 }

                            background: Rectangle {
                                color: "#FFFFFF"
                                radius: 8
                                border.color: parent.activeFocus ? "#4CAF50" : "#CCCCCC"
                                border.width: parent.activeFocus ? 2 : 1.5
                                implicitHeight: 50
                            }
                        }
                    }
                }

                // Min and Max - Centered grid
                GridLayout {
                    columns: 2
                    columnSpacing: 40
                    rowSpacing: 20
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 15

                    ColumnLayout {
                        spacing: 10
                        Layout.preferredWidth: 250
                        Layout.alignment: Qt.AlignHCenter

                        Text {
                            text: "Minimum:"
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            color: "#424242"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        TextField {
                            id: minField
                            Layout.preferredWidth: 200
                            Layout.alignment: Qt.AlignHCenter
                            text: "0.0"
                            font.pixelSize: 16
                            selectByMouse: true
                            padding: 16
                            horizontalAlignment: Text.AlignHCenter

                            background: Rectangle {
                                color: "#FAFAFA"
                                radius: 8
                                border.color: parent.activeFocus ? "#4CAF50" : "#CCCCCC"
                                border.width: parent.activeFocus ? 2 : 1.5
                                implicitHeight: 50
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 10
                        Layout.preferredWidth: 250
                        Layout.alignment: Qt.AlignHCenter

                        Text {
                            text: "Maximum:"
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            color: "#424242"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        TextField {
                            id: maxField
                            Layout.preferredWidth: 200
                            Layout.alignment: Qt.AlignHCenter
                            text: "100.0"
                            font.pixelSize: 16
                            selectByMouse: true
                            padding: 16
                            horizontalAlignment: Text.AlignHCenter

                            background: Rectangle {
                                color: "#FAFAFA"
                                radius: 8
                                border.color: parent.activeFocus ? "#4CAF50" : "#CCCCCC"
                                border.width: parent.activeFocus ? 2 : 1.5
                                implicitHeight: 50
                            }
                        }
                    }
                }            // Unit - Centered
            ColumnLayout {
                spacing: 12
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.topMargin: 15
                Layout.bottomMargin: 30  // Add bottom margin for better accessibility

                Text {
                    text: "Unit (optional):"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: "#2E7D32"
                    Layout.alignment: Qt.AlignLeft
                    Layout.leftMargin: 10
                }

                TextField {
                    id: unitField
                    Layout.preferredWidth: 380
                    Layout.preferredHeight: 50
                    Layout.alignment: Qt.AlignHCenter
                    font.pixelSize: 16
                    selectByMouse: true
                    padding: 16
                    horizontalAlignment: Text.AlignHCenter
                    leftPadding: 20
                    rightPadding: 20

                    background: Rectangle {
                        color: "#FFFFFF"
                        radius: 8
                        border.color: parent.activeFocus ? "#4CAF50" : "#CCCCCC"
                        border.width: parent.activeFocus ? 2 : 1.5
                        implicitHeight: 50
                        
                        // Placeholder text overlay
                        Text {
                            anchors.centerIn: parent
                            text: "e.g., km/h, °C, %, rpm, A, V"
                            color: "#999999"
                            font.pixelSize: 14
                            font.italic: true
                            visible: parent.parent.text.length === 0 && !parent.parent.activeFocus
                        }
                    }
                }
            }

            // Space for better layout - no more inline errors
            Item {
                Layout.preferredHeight: 20  // Just some spacing
            }
        }
    }

    footer: Rectangle {
        color: "#F8F9FA"
        height: 80
        radius: 12
        
        RowLayout {
            anchors.centerIn: parent
            spacing: 20

            Button {
                text: "Cancel"
                Layout.preferredWidth: 140
                Layout.preferredHeight: 50
                
                contentItem: Text {
                    text: parent.text
                    color: "#666666"
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: parent.hovered ? "#F0F0F0" : "#FFFFFF"
                    radius: 10
                    border.color: "#CCCCCC"
                    border.width: 2
                    
                    // Subtle shadow
                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 2
                        color: "transparent"
                        radius: parent.radius
                        border.color: "#00000015"
                        border.width: 1
                        z: -1
                    }
                }
                
                onClicked: addSignalDialog.reject()
            }

            Button {
                text: "Add Signal"
                Layout.preferredWidth: 140
                Layout.preferredHeight: 50
                enabled: signalNameField.text.trim().length > 0

                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? "white" : "#CCCCCC"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: {
                        if (!parent.enabled) return "#E0E0E0"
                        if (parent.pressed) return "#388E3C"
                        if (parent.hovered) return "#66BB6A"
                        return "#4CAF50"
                    }
                    radius: 10
                    
                    // Subtle shadow
                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 2
                        color: "transparent"
                        radius: parent.radius
                        border.color: "#00000020"
                        border.width: 1
                        z: -1
                        visible: parent.parent.enabled
                    }
                }
                
                onClicked: {
                    // Custom validation and signal addition logic
                    addSignalLogic()
                }
            }
        }
    }


    function addSignalLogic() {
        console.log("AddSignalDialog: Starting addSignalLogic")
        console.log("AddSignalDialog: currentMessageName =", currentMessageName)
        console.log("AddSignalDialog: signalName =", signalNameField.text.trim())
        console.log("AddSignalDialog: Raw SpinBox values - startBit =", startBitSpinBox.value, "length =", lengthSpinBox.value)

        // Validate input
        if (signalNameField.text.trim() === "") {
            errorPopup.errorText = "Please enter a signal name."
            errorPopup.open()
            console.log("AddSignalDialog: Error - Signal name is empty")
            return false;
        }

        if (currentMessageName === "") {
            errorPopup.errorText = "No message selected. Please select a message first."
            errorPopup.open()
            console.log("AddSignalDialog: Error - No message selected")
            return false;
        }

        var isLittleEndian = (byteOrderCombo.currentIndex === 0)

        console.log("AddSignalDialog: Validating signal data...")
        
        // Get current values
        var currentStartBit = parseInt(startBitSpinBox.value)
        var currentLength = parseInt(lengthSpinBox.value)
        var currentSignalName = signalNameField.text.trim()
        
        console.log("AddSignalDialog: Current UI values - Start:", currentStartBit, "Length:", currentLength, "Name:", currentSignalName)
        
        // Use enhanced validation with explicit current values
        var validationError = dbcParser.validateSignalData(
            currentMessageName,
            currentSignalName,
            currentStartBit,
            currentLength,
            isLittleEndian
        )
        
        if (validationError !== "") {
            errorPopup.errorText = "Bit overlap detected!\n\n" + validationError + "\n\nPlease adjust the start bit or reduce the signal length."
            errorPopup.open()
            console.log("AddSignalDialog: Validation error:", validationError)
            return false;
        }
        
        // Check if there's enough space for the signal length at current start bit
        var nextAvailableBit = dbcParser.getNextAvailableStartBit(currentMessageName, currentLength)
        if (nextAvailableBit < 0) {
            errorPopup.errorText = "Cannot fit a " + currentLength + "-bit signal in message '" + currentMessageName + "'.\n\nSolutions:\n• Reduce the signal length\n• Use a different message\n• Delete some existing signals"
            errorPopup.open()
            console.log("AddSignalDialog: No space available for", currentLength, "bit signal")
            return false;
        }

        // Get all current values
        var currentFactor = parseFloat(factorField.text) || 1.0
        var currentOffset = parseFloat(offsetField.text) || 0.0
        var currentMin = parseFloat(minField.text) || 0.0
        var currentMax = parseFloat(maxField.text) || 100.0
        var currentUnit = unitField.text || ""
        
        console.log("AddSignalDialog: Adding signal to backend...")
        console.log("AddSignalDialog: CALLING dbcParser.addSignal with length =", currentLength)
        
        // Add the signal
        var success = dbcParser.addSignal(
            currentMessageName,
            currentSignalName,
            currentStartBit,
            currentLength,
            isLittleEndian,
            currentFactor,
            currentOffset,
            currentMin,
            currentMax,
            currentUnit
        );
        
        console.log("AddSignalDialog: addSignal returned:", success)

        if (!success) {
            errorPopup.errorText = "Failed to add signal due to an unexpected error.\n\nPlease check the signal parameters and try again."
            errorPopup.open()
            console.log("AddSignalDialog: Error - addSignal returned false")
            return false;
        }

        console.log("AddSignalDialog: Signal added successfully! Emitting signalAdded signal")
        
        // Emit signal for successful addition
        signalAdded(currentSignalName, currentMessageName)
        
        // Clear fields and close dialog
        clearFields()
        addSignalDialog.accept()
        
        return true;
    }

    onRejected: {
        clearFields()
    }

    function clearFields() {
        console.log("AddSignalDialog: Clearing fields...")
        
        signalNameField.text = ""
        startBitSpinBox.value = 0
        lengthSpinBox.value = 8
        byteOrderCombo.currentIndex = 0
        factorField.text = "1.0"
        offsetField.text = "0.0"
        minField.text = "0.0"
        maxField.text = "100.0"
        unitField.text = ""
        errorPopup.close()  // Close any open error popups
        
        console.log("AddSignalDialog: Fields cleared")
    }
    
    // Function to clear error messages (now just closes popup)
    function clearError() {
        errorPopup.close()
    }

    onOpened: {
        clearFields()
        // Set the start bit to the next available position
        setNextAvailableStartBit()
        // Update bit visualization
        updateBitVisualization()
        signalNameField.forceActiveFocus()
    }
    
    // Function to find and set the next available start bit
    function setNextAvailableStartBit() {
        if (currentMessageName === "") {
            startBitSpinBox.value = 0
            return
        }
        
        console.log("AddSignalDialog: Finding next available start bit for message:", currentMessageName)
        
        // Get the next available start bit from the backend
        var nextBit = dbcParser.getNextAvailableStartBit(currentMessageName, lengthSpinBox.value)
        
        console.log("AddSignalDialog: Next available start bit:", nextBit)
        
        if (nextBit >= 0) {
            startBitSpinBox.value = nextBit
            // Show a brief info message that start bit was auto-set
            if (nextBit > 0) {
                console.log("AddSignalDialog: Auto-set start bit to", nextBit, "to avoid overlaps")
            }
        } else {
            // No space available - just set start bit to 0, don't show popup during length changes
            startBitSpinBox.value = 0
            console.log("AddSignalDialog: No available bit space for", lengthSpinBox.value, "bits - start bit set to 0")
        }
    }
    

    

    
    // Function to force update of bit visualization (simplified)
    function updateBitVisualization() {
        // Simple function for compatibility
        console.log("AddSignalDialog: Start bit auto-assigned to", startBitSpinBox.value)
    }
    


    // Timer removed - using popup errors instead




}
