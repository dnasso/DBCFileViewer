import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

// Bit Editor Component - Similar to the second screenshot
Rectangle {
    id: root
    color: "#f9f9f9"
    border.color: "#e0e0e0"
    border.width: 1
    
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
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 16
                    font.bold: true
                }
                
                background: Rectangle {
                    color: parent.hovered ? "#f44336" : "#e53935"
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
                color: "white"
                border.color: "#e0e0e0"
                
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
                            for (let byteIndex = 7; byteIndex >= 0; byteIndex--) {
                                // Byte label
                                var byteLabel = Qt.createQmlObject(
                                    'import QtQuick; Rectangle { width: 40; height: 25; color: "transparent"; Text { anchors.centerIn: parent; text: ' + byteIndex + '; font.pixelSize: 11; font.bold: true } }',
                                    bitIndicesGrid
                                );
                                
                                // Bit cells for this byte
                                for (let bitIndex = 7; bitIndex >= 0; bitIndex--) {
                                    let bitNumber = byteIndex * 8 + bitIndex;
                                    var bitCell = Qt.createQmlObject(
                                        'import QtQuick; Rectangle { width: 17; height: 25; color: "#f0f0f0"; border.color: "#d0d0d0"; Text { anchors.centerIn: parent; text: ' + bitNumber + '; font.pixelSize: 10 } }',
                                        bitIndicesGrid
                                    );
                                }
                            }
                        }
                    }
                }
            }
            
            // Second column: CAN frame data (HEX and BIN)
            Rectangle {
                Layout.preferredWidth: 360
                Layout.minimumWidth: 300
                Layout.fillHeight: true
                color: "white"
                border.color: "#e0e0e0"
                
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
                            }
                        }
                        
                        Rectangle {
                            width: parent.width / 2
                            height: parent.height
                            
                            Text {
                                anchors.centerIn: parent
                                text: "Data (BIN)"
                                font.pixelSize: 11
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
                                color: index % 2 === 0 ? "#f8f8f8" : "white"
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
                                    font.family: "Monospace"
                                    text: "FF"
                                    readOnly: true
                                    background: Rectangle {
                                        color: "transparent"
                                    }
                                }
                                
                                // Binary value field
                                TextField {
                                    id: binField
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    horizontalAlignment: Text.AlignHCenter
                                    font.family: "Monospace"
                                    text: "11111111"
                                    readOnly: true
                                    background: Rectangle {
                                        color: "transparent"
                                    }
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
                color: "white"
                border.color: "#e0e0e0"
                
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
                color: "white"
                border.color: "#e0e0e0"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 2
                    
                    Text {
                        id: dataValueText
                        text: "Data = 0x2213 = 8723"
                        font.family: "Monospace"
                        font.pixelSize: 12
                    }
                    
                    Text {
                        id: physicalValueText
                        text: "Physical value = 0.125 * 8723 + 0 = 1090.375 rpm"
                        font.family: "Monospace"
                        font.pixelSize: 12
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
        createBitGrids();
        updateBitGrid();
        
        // Create or update signal mask
        createSignalMaskGrid();
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
        
        // Create new bit value cells
        for (let byteIndex = 7; byteIndex >= 0; byteIndex--) {
            for (let bitIndex = 7; bitIndex >= 0; bitIndex--) {
                // Create a cell for the bit value
                var cell = Qt.createQmlObject(
                    'import QtQuick; import QtQuick.Controls; Rectangle { ' +
                    '   width: bitValuesGrid.width / 8; ' +
                    '   height: 25; ' +
                    '   color: "#f0f0f0"; ' +
                    '   border.color: "#d0d0d0"; ' +
                    '   property bool isPartOfSignal: false; ' +
                    '   property bool bitValue: false; ' +
                    '   Text { ' +
                    '       anchors.centerIn: parent; ' +
                    '       text: parent.bitValue ? "1" : "0"; ' +
                    '       font.pixelSize: 11; ' +
                    '       color: parent.isPartOfSignal ? "black" : "#aaaaaa"; ' +
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
                
                // Store reference to the cell
                cell.objectName = "bitValue_" + byteIndex + "_" + bitIndex;
            }
        }
    }
    
    // Create signal mask grid
    function createSignalMaskGrid() {
        // Clear existing grid
        for (let i = signalMaskGrid.children.length - 1; i >= 0; i--) {
            signalMaskGrid.children[i].destroy();
        }
        
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
                    '       text: parent.isPartOfSignal ? "1" : "0"; ' +
                    '       font.pixelSize: 11; ' +
                    '       color: parent.isPartOfSignal ? "#2196F3" : "#aaaaaa"; ' +
                    '   } ' +
                    '}',
                    signalMaskGrid
                );
                
                // Store reference to the cell
                cell.objectName = "signalMask_" + byteIndex + "_" + bitIndex;
                
                // Set if this bit is part of the signal
                var isPartOfSignal = dbcParser.isBitPartOfSignal(root.signalName, byteIndex, bitIndex);
                cell.isPartOfSignal = isPartOfSignal;
            }
        }
    }
    
    // Update the bit grid based on current raw value
    function updateBitGrid() {
        // Get the frame data for display
        var frameData = [];
        var rawValueInt = Math.round(root.rawValue);
        
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
                    bitValueCell.color = isPartOfSignal ? (bitValue ? "#bbdefb" : "#e3f2fd") : "#f0f0f0";
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
