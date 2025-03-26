import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Controls.Material

ApplicationWindow {
    id: window
    visible: true
    width: 900
    height: 700
    title: "DBC File Viewer"
    
    // Apply Material theme
    Material.theme: Material.Light
    Material.accent: Material.Blue
    Material.primary: Material.Blue
    
    FileDialog {
        id: fileDialog
        title: "Select a DBC File"
        nameFilters: ["DBC Files (*.dbc)"]
        onAccepted: {
            dbcParser.loadDbcFile(selectedFile)
            statusText.text = "DBC file loaded: " + selectedFile
        }
    }
    
    // Header with blue background
    Rectangle {
        id: header
        anchors.top: parent.top
        width: parent.width
        height: 60
        color: "#2196F3"
        
        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 20
            text: "DBC File Viewer"
            font.pixelSize: 24
            font.bold: true
            color: "white"
        }
        
        Button {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 20
            text: "Load DBC File"
            
            contentItem: Text {
                text: parent.text
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            background: Rectangle {
                implicitWidth: 120
                implicitHeight: 40
                color: parent.hovered ? "#1E88E5" : "#0D47A1"
                radius: 4
            }
            
            onClicked: fileDialog.open()
        }
    }
    
    // Status bar
    Rectangle {
        id: statusBar
        anchors.top: header.bottom
        width: parent.width
        height: 40
        color: "#4CAF50"
        
        Text {
            id: statusText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 20
            text: "No file loaded"
            font.pixelSize: 14
            color: "white"
        }
    }
    
    // Main content
    ColumnLayout {
        anchors.top: statusBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        spacing: 10
        
        // CAN Messages section
        GroupBox {
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            title: "CAN Messages"
            
            background: Rectangle {
                color: "white"
                border.color: "#E0E0E0"
                border.width: 1
                radius: 4
            }

            ScrollView {
                anchors.fill: parent
                clip: true

                ListView {
                    id: messageListView
                    anchors.fill: parent
                    clip: true
                    model: dbcParser.messageModel

                    delegate: ItemDelegate {
                        width: parent.width
                        height: 40
                        text: modelData
                        highlighted: ListView.isCurrentItem

                        background: Rectangle {
                            color: highlighted ? "#E3F2FD" : (index % 2 == 0 ? "#F5F5F5" : "white")
                            radius: 2
                        }

                        onClicked: {
                            messageListView.currentIndex = index
                            dbcParser.selectMessage(modelData)
                        }
                    }
                }
            }
        }
        
        // Show all signals checkbox
        CheckBox {
            id: showAllSignals
            text: "Show all signals"
            onCheckedChanged: dbcParser.setShowAllSignals(checked)
        }
        
        // Signal Details section
        GroupBox {
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: "Signal Details"
            
            background: Rectangle {
                color: "white"
                border.color: "#E0E0E0"
                border.width: 1
                radius: 4
            }
            
            ScrollView {
                anchors.fill: parent
                clip: true
                
                Column {
                    width: parent.width
                    spacing: 10
                    
                    Repeater {
                        id: signalDataRepeater
                        model: dbcParser.signalModel
                        
                        delegate: Rectangle {
                            width: parent.width
                            height: signalColumn.height + 20
                            color: "#F9F9F9"
                            border.color: "#E0E0E0"
                            border.width: 1
                            radius: 4
                            
                            Column {
                                id: signalColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 10
                                spacing: 5
                                
                                // Signal name and basic info
                                Text {
                                    text: modelData.name
                                    font.bold: true
                                    font.pixelSize: 16
                                    color: "#2196F3"
                                }
                                
                                // Signal properties in a grid
                                Grid {
                                    columns: 4
                                    spacing: 10
                                    width: parent.width
                                    
                                    Text { text: "Start Bit:"; font.pixelSize: 12 }
                                    Text { text: modelData.startBit; font.pixelSize: 12 }
                                    
                                    Text { text: "Length:"; font.pixelSize: 12 }
                                    Text { text: modelData.length + " bits"; font.pixelSize: 12 }
                                    
                                    Text { text: "Endian:"; font.pixelSize: 12 }
                                    Text { text: modelData.littleEndian ? "Little" : "Big"; font.pixelSize: 12 }
                                    
                                    Text { text: "Factor:"; font.pixelSize: 12 }
                                    Text { text: modelData.factor; font.pixelSize: 12 }
                                    
                                    Text { text: "Offset:"; font.pixelSize: 12 }
                                    Text { text: modelData.offset; font.pixelSize: 12 }
                                    
                                    Text { text: "Range:"; font.pixelSize: 12 }
                                    Text { text: modelData.min + " to " + modelData.max + " " + modelData.unit; font.pixelSize: 12 }
                                }

                                // Offset Controls
                                Text {
                                    text: "Offset:"
                                    font.pixelSize: 14
                                    topPadding: 10
                                }
                                Row {
                                    width: parent.width
                                    spacing: 10

                                    SpinBox {
                                        //id: valueSpinBox
                                        from: -999999
                                        to: 999999
                                        value: modelData.offset
                                        editable: true
                                        stepSize: 1
                                        //onValueChanged: dbcParser.updateSignalValue(modelData.name, value)
                                        // We need backend for this
                                    }
                                }

                                // Factor Controls
                                Text {
                                    text: "Factor:"
                                    font.pixelSize: 14
                                    topPadding: 10
                                }
                                Row {
                                    width: parent.width
                                    spacing: 10

                                    SpinBox {
                                        //id: valueSpinBox
                                        from: -999999
                                        to: 999999
                                        value: modelData.factor
                                        editable: true
                                        stepSize: 1
                                        //onValueChanged: dbcParser.updateSignalValue(modelData.name, value)
                                        // We need backend for this
                                    }
                                }
                                
                                // Value controls
                                Text {
                                    text: "Value:"
                                    font.pixelSize: 14
                                    topPadding: 10
                                }
                                Row {
                                    width: parent.width
                                    spacing: 10
                                    
                                    SpinBox {
                                        id: valueSpinBox
                                        from: modelData.min !== modelData.max ? modelData.min : -999999
                                        to: modelData.min !== modelData.max ? modelData.max : 999999
                                        value: modelData.value
                                        editable: true
                                        stepSize: 1
                                        onValueChanged: dbcParser.updateSignalValue(modelData.name, value)
                                    }
                                    
                                    Slider {
                                        width: parent.width - valueSpinBox.width - 20
                                        from: valueSpinBox.from
                                        to: valueSpinBox.to
                                        value: valueSpinBox.value
                                        onMoved: valueSpinBox.value = value
                                        visible: modelData.min !== modelData.max
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Generated CAN Frame section
        GroupBox {
            Layout.fillWidth: true
            title: "Generated CAN Frame"
            
            background: Rectangle {
                color: "white"
                border.color: "#E0E0E0"
                border.width: 1
                radius: 4
            }
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 10
                
                TextArea {
                    Layout.fillWidth: true
                    readOnly: true
                    text: dbcParser.generatedCanFrame
                    font.family: "Courier"
                    background: Rectangle {
                        color: "#F5F5F5"
                        border.color: "#E0E0E0"
                        border.width: 1
                    }
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    
                    Button {
                        text: "Generate Frame"
                        onClicked: dbcParser.generateCanFrame()
                        
                        background: Rectangle {
                            implicitWidth: 120
                            implicitHeight: 40
                            color: parent.hovered ? "#1976D2" : "#2196F3"
                            radius: 4
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    
                    Button {
                        text: "Copy"
                        onClicked: {
                            outputField.selectAll()
                            outputField.copy()
                        }
                        
                        background: Rectangle {
                            implicitWidth: 80
                            implicitHeight: 40
                            color: parent.hovered ? "#757575" : "#9E9E9E"
                            radius: 4
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
