import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

// Bit Editor Component - Similar to the second screenshot
Rectangle {
    id: root
    color: themeManager.panelColor
    border.color: themeManager.borderColor
    border.width: 1
    
    property string signalName: ""
    property double signalValue: 0
    property int signalStartBit: 0
    property int signalLength: 0
    property bool signalLittleEndian: true
    property var bitValues: []
    property double rawValue: 0
    
    // Handle theme changes - recreate grids when theme changes
    Connections {
        target: themeManager
        function onThemeChanged() {
            // Recreate the grids with updated colors
            createBitIndicesGrid()
            createBitGrids()
            createSignalMaskGrid()
            updateBitGrid()
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        
        // Header row with close button
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: "CAN signal preview: " + signalName
                font.pixelSize: 14
                font.bold: true
                color: "#2196F3"
            }
            
            Item { Layout.fillWidth: true }
            
            Button {
                text: "×"
                implicitWidth: 30
                implicitHeight: 30
                
                contentItem: Text {
                    text: parent.text
                    color: themeManager.isDarkTheme ? "#FFFFFF" : "#FFFFFF"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 16
                    font.bold: true
                }
                
                background: Rectangle {
                    color: parent.hovered ? (themeManager.isDarkTheme ? "#E53935" : "#D32F2F") : (themeManager.isDarkTheme ? "#C62828" : "#F44336")
                    radius: 15
                }
                
                onClicked: root.visible = false
            }
        }
        
        // Value input section
        RowLayout {
            Layout.fillWidth: true
            spacing: 15
            
            Text {
                text: "Physical Value:"
                font.pixelSize: 13
                color: themeManager.textColor
            }
            
            TextField {
                id: physicalValueField
                Layout.preferredWidth: 120
                text: root.signalValue.toString()
                validator: DoubleValidator {}
                selectByMouse: true
                onTextChanged: {
                    if (text && text.length > 0) {
                        var physValue = parseFloat(text);
                        root.rawValue = dbcParser.calculateRawValue(root.signalName, physValue);
                        rawValueField.text = Math.round(root.rawValue).toString();
                        updateCalculationText();
                        updateBitGrid();
                    }
                }
            }
            
            Text {
                text: "Raw Value:"
                font.pixelSize: 13
                color: themeManager.textColor
            }
            
            TextField {
                id: rawValueField
                Layout.preferredWidth: 120
                text: "0"
                validator: IntValidator {}
                selectByMouse: true
                onTextChanged: {
                    if (text && text.length > 0) {
                        root.rawValue = parseInt(text);
                        var physValue = dbcParser.calculatePhysicalValue(root.signalName, root.rawValue);
                        physicalValueField.text = physValue.toString();
                        updateCalculationText();
                        updateBitGrid();
                    }
                }
            }
            
            Item { Layout.fillWidth: true }
            
            ComboBox {
                id: displayMode
                model: ["Decimal", "Hexadecimal", "Binary"]
                currentIndex: 0
                onCurrentIndexChanged: updateBitGrid()
            }
        }
        
        // Main bit manipulation area
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 3
            rowSpacing: 10
            columnSpacing: 10
            
            // First column: Bit indices grid
            Rectangle {
                Layout.preferredWidth: 200
                Layout.minimumWidth: 180
                Layout.fillHeight: true
                color: themeManager.panelColor
                border.color: themeManager.borderColor
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 0
                    
                    Text {
                        text: "Editor bit indices"
                        font.pixelSize: 12
                        font.bold: true
                        Layout.alignment: Qt.AlignCenter
                        Layout.bottomMargin: 5
                        color: themeManager.textColor
                    }
                    
                    // Header row with bit numbers
                    Row {
                        Layout.fillWidth: true
                        height: 25
                        spacing: 0
                        
                        Rectangle {
                            width: 40
                            height: parent.height
                            color: "transparent"
                        }
                        
                        Repeater {
                            model: 8
                            
                            Rectangle {
                                width: 17
                                height: 25
                                color: "transparent"
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: 7 - index
                                    font.pixelSize: 11
                                    color: themeManager.textColor
                                }
                            }
                        }
                    }
                    
                    // Bit index grid
                    GridLayout {
                        id: bitIndicesGrid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 9
                        rows: 8
                        columnSpacing: 0
                        rowSpacing: 0
                        
                        // Generate the 8×8 grid of bit indices
                        Component.onCompleted: {
                            Qt.callLater(createBitIndicesGrid)
                        }
                    }
                }
            }
            
            // Second column: CAN frame data (HEX and BIN)
            Rectangle {
                Layout.preferredWidth: 360
                Layout.minimumWidth: 300
                Layout.fillHeight: true
                color: themeManager.panelColor
                border.color: themeManager.borderColor
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 0
                    
                    Text {
                        text: "CAN frame"
                        font.pixelSize: 12
                        font.bold: true
                        Layout.alignment: Qt.AlignCenter
                        Layout.bottomMargin: 5
                        color: themeManager.textColor
                    }
                    
                    // Header row
                    Row {
                        Layout.fillWidth: true
                        height: 25
                        
                        Rectangle {
                            width: parent.width / 2
                            height: parent.height
                            
                            Text {
                                anchors.centerIn: parent
                                text: "Data (HEX)"
                                font.pixelSize: 11
                                color: themeManager.textColor
                            }
                        }
                        
                        Rectangle {
                            width: parent.width / 2
                            height: parent.height
                            
                            Text {
                                anchors.centerIn: parent
                                text: "Data (BIN)"
                                font.pixelSize: 11
                                color: themeManager.textColor
                            }
                        }
                    }
                    
                    // Data rows
                    ListView {
                        id: canFrameDataView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: 8  // 8 bytes
                        
                        ScrollBar.vertical: ScrollBar {
                            active: true
                            policy: ScrollBar.AsNeeded
                        }
                        
                        delegate: Item {
                            width: canFrameDataView.width
                            height: 25
                            
                            Rectangle {
                                anchors.fill: parent
                                color: index % 2 === 0 ? themeManager.panelColor : (themeManager.isDarkTheme ? "#252525" : "#f8f8f8")
                            }
                            
                            RowLayout {
                                anchors.fill: parent
                                spacing: 0
                                
                                // HEX value field
                                TextField {
                                    id: hexField
                                    Layout.preferredWidth: parent.width / 2
                                    Layout.fillHeight: true
                                    horizontalAlignment: Text.AlignHCenter
                                    font.family: "Monaco"
                                    text: "FF"
                                    readOnly: true
                                    background: Rectangle {
                                        color: "transparent"
                                    }
                                    color: themeManager.textColor
                                }
                                
                                // Binary value field
                                TextField {
                                    id: binField
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    horizontalAlignment: Text.AlignHCenter
                                    font.family: "Monaco"
                                    text: "11111111"
                                    readOnly: true
                                    background: Rectangle {
                                        color: "transparent"
                                    }
                                    color: themeManager.textColor
                                }
                            }
                        }
                    }
                }
            }
            
            // Third column: Bit data values and signal mask
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: themeManager.panelColor
                border.color: themeManager.borderColor
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 0
                    
                    TabBar {
                        id: dataTabBar
                        Layout.fillWidth: true
                        
                        TabButton {
                            text: "Bit data values"
                            width: implicitWidth
                        }
                        
                        TabButton {
                            text: "Signal mask (BIN)"
                            width: implicitWidth
                        }
                    }
                    
                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: dataTabBar.currentIndex
                        
                        // Bit data values tab
                        Rectangle {
                            color: "transparent"
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.topMargin: 5
                                spacing: 0
                                
                                // Header row with bit indices
                                Row {
                                    Layout.fillWidth: true
                                    height: 25
                                    spacing: 0
                                    
                                    Repeater {
                                        model: 8
                                        
                                        Rectangle {
                                            width: parent.width / 8
                                            height: 25
                                            color: "transparent"
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: 7 - index
                                                font.pixelSize: 11
                                                color: themeManager.textColor
                                            }
                                        }
                                    }
                                }
                                
                                // Bit value grid
                                GridLayout {
                                    id: bitValuesGrid
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    columns: 8
                                    rows: 8
                                    columnSpacing: 0
                                    rowSpacing: 0
                                    
                                    // Dynamically filled with bit values
                                }
                            }
                        }
                        
                        // Signal mask tab
                        Rectangle {
                            color: "transparent"
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.topMargin: 5
                                spacing: 0
                                
                                // Header row with bit indices
                                Row {
                                    Layout.fillWidth: true
                                    height: 25
                                    spacing: 0
                                    
                                    Repeater {
                                        model: 8
                                        
                                        Rectangle {
                                            width: parent.width / 8
                                            height: 25
                                            color: "transparent"
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: 7 - index
                                                font.pixelSize: 11
                                                color: themeManager.textColor
                                            }
                                        }
                                    }
                                }
                                
                                // Signal mask grid
                                GridLayout {
                                    id: signalMaskGrid
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    columns: 8
                                    rows: 8
                                    columnSpacing: 0
                                    rowSpacing: 0
                                    
                                    // Dynamically filled with signal mask
                                }
                            }
                        }
                    }
                }
            }
            
            // Empty spacer
            Item {
                Layout.columnSpan: 2
                Layout.preferredHeight: 5
            }
            
            // Calculation text at the bottom
            Rectangle {
                Layout.columnSpan: 1
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                color: themeManager.panelColor
                border.color: themeManager.borderColor
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 2
                    
                    Text {
                        id: dataValueText
                        text: "Data = 0x2213 = 8723"
                        font.family: "Monaco"
                        font.pixelSize: 12
                        color: themeManager.textColor
                    }
                    
                    Text {
                        id: physicalValueText
                        text: "Physical value = 0.125 * 8723 + 0 = 1090.375 rpm"
                        font.family: "Monaco"
                        font.pixelSize: 12
                        color: themeManager.textColor
                    }
                }
            }
        }
    }
    
    // Initialize the bit editor display
    function initializeDisplay() {
        // Get raw value from the current signal value
        root.rawValue = dbcParser.calculateRawValue(root.signalName, root.signalValue);
        rawValueField.text = Math.round(root.rawValue).toString();
        
        // Update calculation text
        updateCalculationText();
        
        // Create or update bit grids
        createBitIndicesGrid();
        createBitGrids();
        updateBitGrid();
        
        // Create or update signal mask
        createSignalMaskGrid();
    }
    
    // Create bit indices grid (recreated on theme change)
    function createBitIndicesGrid() {
        // Clear existing grid
        var children = bitIndicesGrid.children;
        while (children.length > 0) {
            children[0].destroy();
        }
        
        // Create new bit indices cells
        for (let byteIndex = 7; byteIndex >= 0; byteIndex--) {
            // Byte label
            var byteLabel = Qt.createQmlObject(
                'import QtQuick; Rectangle { width: 40; height: 25; color: "transparent" }',
                bitIndicesGrid
            );
            var byteLabelText = Qt.createQmlObject(
                'import QtQuick; Text { anchors.centerIn: parent; font.pixelSize: 11; font.bold: true }',
                byteLabel
            );
            byteLabelText.text = byteIndex.toString();
            byteLabelText.color = themeManager.labelTextColor;
            
            // Bit cells for this byte
            for (let bitIndex = 7; bitIndex >= 0; bitIndex--) {
                let bitNumber = byteIndex * 8 + bitIndex;
                var bitCell = Qt.createQmlObject(
                    'import QtQuick; Rectangle { width: 17; height: 25 }',
                    bitIndicesGrid
                );
                // Use bitIndicesColor for proper dark/light mode styling
                bitCell.color = themeManager.bitIndicesColor;
                bitCell.border.color = themeManager.borderColor;
                bitCell.border.width = 1;
                
                var bitText = Qt.createQmlObject(
                    'import QtQuick; Text { anchors.centerIn: parent; font.pixelSize: 10 }',
                    bitCell
                );
                bitText.text = bitNumber.toString();
                bitText.color = themeManager.bitIndicesTextColor;
            }
        }
    }
    
    // Update the calculation text fields
    function updateCalculationText() {
        var calculationText = dbcParser.formatPhysicalValueCalculation(root.signalName, root.rawValue);
        var lines = calculationText.split('\n');
        
        if (lines.length >= 2) {
            dataValueText.text = lines[0];
            physicalValueText.text = lines[1];
        }
    }
    
    // Create bit value grids
    function createBitGrids() {
        // Clear existing grids
        for (let i = bitValuesGrid.children.length - 1; i >= 0; i--) {
            bitValuesGrid.children[i].destroy();
        }
        
        // Determine highlight color based on theme
        var highlightColor = themeManager.isDarkTheme ? "#4CAF50" : "#1976D2";
        
        // Create new bit value cells
        for (let byteIndex = 7; byteIndex >= 0; byteIndex--) {
            for (let bitIndex = 7; bitIndex >= 0; bitIndex--) {
                // Create a cell for the bit value
                var cell = Qt.createQmlObject(
                    'import QtQuick; import QtQuick.Controls; Rectangle { ' +
                    '   width: bitValuesGrid.width / 8; ' +
                    '   height: 25; ' +
                    '   border.width: 1; ' +
                    '   property bool isPartOfSignal: false; ' +
                    '   property bool bitValue: false; ' +
                    '   Text { ' +
                    '       anchors.centerIn: parent; ' +
                    '       font.pixelSize: 11; ' +
                    '   } ' +
                    '   MouseArea { ' +
                    '       anchors.fill: parent; ' +
                    '       onClicked: { ' +
                    '           if (parent.isPartOfSignal) { ' +
                    '               toggleBit(' + byteIndex + ', ' + bitIndex + '); ' +
                    '           } ' +
                    '       } ' +
                    '   } ' +
                    '}',
                    bitValuesGrid
                );
                
                cell.color = themeManager.panelColor;
                cell.border.color = themeManager.borderColor;
                var text = cell.children[0];
                text.text = "0";
                text.color = themeManager.textColor;
                
                // Store reference to the cell
                cell.objectName = "bitValue_" + byteIndex + "_" + bitIndex;
                cell.highlightColor = highlightColor;
            }
        }
    }
    
    // Create signal mask grid
    function createSignalMaskGrid() {
        // Clear existing grid
        for (let i = signalMaskGrid.children.length - 1; i >= 0; i--) {
            signalMaskGrid.children[i].destroy();
        }
        
        // Determine highlight color based on theme
        var highlightColor = themeManager.isDarkTheme ? "#4CAF50" : "#1976D2";
        
        // Create new signal mask cells
        for (let byteIndex = 7; byteIndex >= 0; byteIndex--) {
            for (let bitIndex = 7; bitIndex >= 0; bitIndex--) {
                // Create a cell for the signal mask
                var cell = Qt.createQmlObject(
                    'import QtQuick; Rectangle { ' +
                    '   width: signalMaskGrid.width / 8; ' +
                    '   height: 25; ' +
                    '   color: "transparent"; ' +
                    '   property bool isPartOfSignal: false; ' +
                    '   Text { ' +
                    '       anchors.centerIn: parent; ' +
                    '       font.pixelSize: 11; ' +
                    '   } ' +
                    '}',
                    signalMaskGrid
                );
                
                var text = cell.children[0];
                text.text = "0";
                text.color = highlightColor;
                
                // Store reference to the cell
                cell.objectName = "signalMask_" + byteIndex + "_" + bitIndex;
                
                // Set if this bit is part of the signal
                var isPartOfSignal = dbcParser.isBitPartOfSignal(root.signalName, byteIndex, bitIndex);
                cell.isPartOfSignal = isPartOfSignal;
                if (!isPartOfSignal) {
                    text.color = themeManager.secondaryTextColor;
                }
            }
        }
    }
    
    // Update the bit grid based on current raw value
    function updateBitGrid() {
        // Get the frame data for display
        var frameData = [];
        var rawValueInt = Math.round(root.rawValue);
        
        // Determine highlight color based on theme
        var highlightColor = themeManager.isDarkTheme ? "#4CAF50" : "#1976D2";
        
        // Update CAN frame data display (hex and binary)
        for (let byteIndex = 7; byteIndex >= 0; byteIndex--) {
            let byteValue = 0;
            
            // For each bit in the byte
            for (let bitIndex = 7; bitIndex >= 0; bitIndex--) {
                // Check if this bit is part of the signal and get its value
                var isPartOfSignal = dbcParser.isBitPartOfSignal(root.signalName, byteIndex, bitIndex);
                var bitValue = false;
                
                if (isPartOfSignal) {
                    bitValue = dbcParser.getBit(root.signalName, byteIndex, bitIndex);
                    if (bitValue) {
                        byteValue |= (1 << bitIndex);
                    }
                }
                
                // Find and update the bit value cell
                var bitValueCell = findBitValueCell(byteIndex, bitIndex);
                if (bitValueCell) {
                    bitValueCell.isPartOfSignal = isPartOfSignal;
                    bitValueCell.bitValue = bitValue;
                    var text = bitValueCell.children[0];
                    text.text = bitValue ? "1" : "0";
                    
                    // Use theme-aware colors: highlight for active bits, subtle for inactive
                    if (isPartOfSignal) {
                        // Active signal bits: highlight when set, dim when not set
                        bitValueCell.color = bitValue ? highlightColor : themeManager.panelColor;
                        text.color = bitValue ? "white" : themeManager.textColor;
                    } else {
                        // Inactive bits: use panel color
                        bitValueCell.color = themeManager.panelColor;
                        text.color = themeManager.secondaryTextColor;
                    }
                }
            }
            
            // Store for CAN frame data display
            frameData.push(byteValue);
            
            // Update the display in the ListView
            var hexValue = byteValue.toString(16).toUpperCase().padStart(2, '0');
            var binValue = byteValue.toString(2).padStart(8, '0');
            
            if (canFrameDataView.itemAtIndex(7 - byteIndex)) {
                var item = canFrameDataView.itemAtIndex(7 - byteIndex);
                var hexField = item.children[1].children[0];
                var binField = item.children[1].children[1];
                
                hexField.text = hexValue;
                binField.text = binValue;
            }
        }
    }
    
    // Find a bit value cell by byte and bit index
    function findBitValueCell(byteIndex, bitIndex) {
        for (let i = 0; i < bitValuesGrid.children.length; i++) {
            var cell = bitValuesGrid.children[i];
            if (cell.objectName === "bitValue_" + byteIndex + "_" + bitIndex) {
                return cell;
            }
        }
        return null;
    }
    
    // Toggle a bit value
    function toggleBit(byteIndex, bitIndex) {
        var cell = findBitValueCell(byteIndex, bitIndex);
        if (cell && cell.isPartOfSignal) {
            // Toggle the bit in the DBC parser
            dbcParser.setBit(root.signalName, byteIndex, bitIndex, !cell.bitValue);
            
            // Update the raw value
            root.rawValue = dbcParser.calculateRawValue(root.signalName, root.signalValue);
            rawValueField.text = Math.round(root.rawValue).toString();
            
            // Update the physical value
            var physValue = dbcParser.calculatePhysicalValue(root.signalName, root.rawValue);
            physicalValueField.text = physValue.toString();
            
            // Update the bit grid
            updateBitGrid();
            
            // Update the calculation text
            updateCalculationText();
        }
    }
}
