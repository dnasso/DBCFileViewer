import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

Dialog {
    id: addSignalDialog
    title: "Add New Signal"
    modal: true
    anchors.centerIn: parent
    width: 750  // Increased width for better centering
    height: 750
    padding: 0

    property string currentMessageName: ""

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
        
        ColumnLayout {
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
                            if (parent.text.length === 0) return "#FF5722"
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
                        color: parent.text.length > 0 ? "#4CAF50" : "#FF5722"
                        visible: parent.text.length > 0 || parent.activeFocus
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

                        Text {
                            text: "Start Bit:"
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            color: "#424242"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        SpinBox {
                            id: startBitSpinBox
                            Layout.preferredWidth: 200  // Fixed width
                            Layout.alignment: Qt.AlignHCenter
                            from: 0
                            to: 63
                            value: 0
                            editable: true

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
                }            // Byte Order - Centered
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
            }            // Error Label - Centered
            Rectangle {
                Layout.preferredWidth: 380
                Layout.alignment: Qt.AlignHCenter
                height: errorLabel.visible ? errorLabel.implicitHeight + 20 : 0
                color: errorLabel.visible ? "#FFEBEE" : "transparent"
                radius: 8
                visible: errorLabel.visible
                Layout.bottomMargin: 20

                Text {
                    id: errorLabel
                    anchors.centerIn: parent
                    width: parent.width - 20
                    color: "#D32F2F"
                    wrapMode: Text.WordWrap
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                }
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
        errorLabel.text = ""
        errorLabel.color = "#D32F2F"  // Reset to error color

        // Validate input
        if (signalNameField.text.trim() === "") {
            errorLabel.text = "Please enter a signal name"
            return false;
        }

        if (currentMessageName === "") {
            errorLabel.text = "No message selected"
            return false;
        }

        var isLittleEndian = (byteOrderCombo.currentIndex === 0)

        // Use enhanced validation
        var validationError = dbcParser.validateSignalData(
            currentMessageName,
            signalNameField.text.trim(),
            startBitSpinBox.value,
            lengthSpinBox.value,
            isLittleEndian
        )
        
        if (validationError !== "") {
            errorLabel.text = validationError
            return false;
        }

        // Add the signal
        var success = dbcParser.addSignal(
            currentMessageName,
            signalNameField.text.trim(),
            startBitSpinBox.value,
            lengthSpinBox.value,
            isLittleEndian,
            parseFloat(factorField.text),
            parseFloat(offsetField.text),
            parseFloat(minField.text),
            parseFloat(maxField.text),
            unitField.text
        );

        if (!success) {
            errorLabel.text = "Failed to add signal due to an unexpected error"
            return false;
        }

        // Clear fields for next use but keep dialog open for multiple additions
        signalNameField.text = ""
        signalNameField.forceActiveFocus()

        // Increment start bit for next signal
        startBitSpinBox.value += lengthSpinBox.value

        // Show success message temporarily
        errorLabel.text = "Signal '" + signalNameField.text.trim() + "' added successfully! You can add another signal or click Cancel to close."
        errorLabel.color = "#2E7D32"

        // Reset error color after delay
        timer.restart()
        
        return true;
    }

    onRejected: {
        clearFields()
    }

    function clearFields() {
        signalNameField.text = ""
        startBitSpinBox.value = 0
        lengthSpinBox.value = 8
        byteOrderCombo.currentIndex = 0
        factorField.text = "1.0"
        offsetField.text = "0.0"
        minField.text = "0.0"
        maxField.text = "100.0"
        unitField.text = ""
        errorLabel.text = ""
        errorLabel.color = "#D32F2F"
    }

    onOpened: {
        clearFields()
        signalNameField.forceActiveFocus()
    }

    Timer {
        id: timer
        interval: 2000
        onTriggered: {
            errorLabel.text = ""
        }
    }
}
