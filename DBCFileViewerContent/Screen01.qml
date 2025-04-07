

/*
This is a UI file (.ui.qml) that is intended to be edited in Qt Design Studio only.
It is supposed to be strictly declarative and only uses a subset of QML. If you edit
this file manually, you might introduce QML code that is not supported by Qt Design Studio.
Check out https://doc.qt.io/qtcreator/creator-quick-ui-forms.html for details on .ui.qml files.
*/
import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import DBCFileViewer

//notes display mode, send mode
//permissions system
import QtQuick.Layouts

Rectangle {
    id: rectangle
    width: 1046
    height: 788

    color: Constants.backgroundColor

    Button {
        id: button
        text: qsTr("Press me")
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 450
        anchors.horizontalCenterOffset: 214
        checkable: true
        anchors.horizontalCenter: parent.horizontalCenter

        Connections {
            target: button
            onClicked: animation.start()
        }
    }

    Text {
        id: label
        text: qsTr("Hello DBCFileViewer")
        anchors.top: button.bottom
        font.family: Constants.font.family
        anchors.topMargin: 20
        anchors.horizontalCenterOffset: 214
        anchors.horizontalCenter: parent.horizontalCenter

        SequentialAnimation {
            id: animation

            ColorAnimation {
                id: colorAnimation1
                target: rectangle
                property: "color"
                to: "#2294c6"
                from: Constants.backgroundColor
            }

            ColorAnimation {
                id: colorAnimation2
                target: rectangle
                property: "color"
                to: Constants.backgroundColor
                from: "#2294c6"
            }
        }
    }

    GroupBox {
        id: canMessagesBox
        width: 961
        height: 285
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 41
        anchors.topMargin: 159
        font.pointSize: 11
        title: qsTr("CAN Messages")

        Column {
            id: cmColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.topMargin: 60
            anchors.bottomMargin: 10

            Repeater {
                id: cmRepeater
                anchors.fill: parent
                model: ListModel {
                    id: cmListModel
                    ListElement {
                        //name: "New Message Row"
                    }
                    function createListElement() {}
                }

                Rectangle {
                    id: cmRectangle
                    x: -7
                    y: -358
                    width: 1010
                    height: 42
                    color: "#00ffffff"

                    Row {
                        id: cmRow
                        anchors.fill: parent
                        spacing: 10

                        RadioButton {
                            id: cmRadioButton
                            checked: true
                            width: 28
                            text: ""
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.topMargin: 7
                            anchors.bottomMargin: 7
                            state: ""
                            //text: qsTr("Radio Button")
                        }

                        TextField {
                            id: cmNameField
                            width: 120
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.topMargin: 7
                            anchors.bottomMargin: 7
                            placeholderText: qsTr("Text Field")
                        }

                        TextField {
                            id: cmIdField
                            width: 120
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.topMargin: 7
                            anchors.bottomMargin: 7
                            placeholderText: qsTr("Text Field")
                        }

                        ComboBox {
                            id: cmTypeComboBox
                            width: 260
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.topMargin: 7
                            anchors.bottomMargin: 7
                        }

                        TextField {
                            id: cmDLCField
                            width: 100
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.topMargin: 7
                            anchors.bottomMargin: 7
                            placeholderText: qsTr("Text Field")
                        }

                        TextField {
                            id: cmCommentField
                            width: 240
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.topMargin: 7
                            anchors.bottomMargin: 7
                        }
                    }
                }
            }
        }

        Button {
            id: cmPlusButton
            x: 134
            width: 41
            height: 37
            text: qsTr("+")
            anchors.top: parent.top
            anchors.topMargin: -10
            anchors.bottomMargin: -1
            rightPadding: 15
            display: AbstractButton.TextOnly
            bottomPadding: 16
            topPadding: 10
            font.bold: true
            leftPadding: 15
            font.pointSize: 20

            Connections {
                target: cmPlusButton
                onClicked: {
                    cmListModel.append(cmListModel.createListElement())
                }
            }
        }

        Button {
            id: cmMinusButton
            x: 187
            width: 41
            height: 37
            text: qsTr("-")
            anchors.top: parent.top
            anchors.topMargin: -10
            anchors.bottomMargin: -1
            rightPadding: 15
            display: AbstractButton.TextOnly
            font.bold: true
            bottomPadding: 18
            topPadding: 8
            leftPadding: 15
            font.pointSize: 30
        }

        Button {
            id: saveDBCButton
            y: -68
            height: 52
            text: qsTr("Save DBC")
            anchors.left: parent.left
            anchors.right: parent.left
            anchors.bottom: canMessagesBox.top
            anchors.leftMargin: 125
            anchors.rightMargin: -243
            anchors.bottomMargin: 16

            Connections {
                target: saveDBCButton
                function onClicked() {
                    fileDialog.save()
                } //not implemented yet
            }
        }

        Button {
            id: loadDBCButton
            x: 0
            y: -68
            text: qsTr("Load DBC")
            anchors.right: canMessagesBox.left
            anchors.bottom: canMessagesBox.top
            anchors.rightMargin: -114
            anchors.bottomMargin: 16
            flat: false

            Connections {
                target: loadDBCButton
                function onClicked() {
                    fileDialog.open()
                }
            }
        }

        ComboBox {
            id: messagePresetsComboBox
            y: -68
            height: 56
            anchors.left: saveDBCButton.right
            anchors.right: parent.right
            anchors.bottom: canMessagesBox.top
            anchors.leftMargin: 37
            anchors.rightMargin: 8
            anchors.bottomMargin: 12
        }

        Text {
            id: presetsText
            y: -99
            width: 218
            height: 25
            text: qsTr("Available Message Presets:")
            anchors.left: saveDBCButton.right
            anchors.bottom: canMessagesBox.top
            anchors.leftMargin: 37
            anchors.bottomMargin: 74
            font.pixelSize: 16
        }

        Text {
            id: cmNameText
            x: 40
            y: 30
            height: 24
            text: qsTr("Name")
            font.pixelSize: 16
            horizontalAlignment: Text.AlignLeft
            Layout.leftMargin: 10
            Layout.rightMargin: 3
            Layout.preferredWidth: 57
            Layout.preferredHeight: 23
        }

        Rectangle {
            id: cmCanIdRectangle
            x: 5
            y: 76
            width: 170
            height: 30
            opacity: 1
            color: "#00ffffff"
            Layout.fillHeight: true

            Text {
                id: canIdText
                x: 166
                text: qsTr("CAN ID")
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 16
                anchors.verticalCenterOffset: -48
                Layout.preferredWidth: 57
                Layout.preferredHeight: 24
            }

            ComboBox {
                id: hexComboBox
                x: 211
                width: 85
                height: 30
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -49
                font.pointSize: 13
                model: ["Hex", "Dec"]
                displayText: "Hex"
                Layout.preferredWidth: 90
                Layout.preferredHeight: 29
            }
        }

        Text {
            id: cmTypeText
            x: 303
            y: 32
            height: 24
            text: qsTr("Type")
            font.pixelSize: 16
            Layout.margins: 0
            Layout.leftMargin: 0
            Layout.rightMargin: 0
            Layout.preferredWidth: 57
            Layout.preferredHeight: 22
        }

        Text {
            id: cmDLCText
            x: 574
            y: 32
            height: 24
            text: qsTr("DLC")
            font.pixelSize: 16
            Layout.preferredWidth: 57
            Layout.preferredHeight: 22
        }

        Text {
            id: cmCommentText
            x: 685
            y: 30
            height: 24
            text: qsTr("Comment")
            font.pixelSize: 16
            Layout.preferredWidth: 95
            Layout.preferredHeight: 24
        }
    }

    GroupBox {
        id: canSignalsBox
        x: 41
        y: 458
        width: 961
        height: 251
        title: qsTr("CAN Signals (EEC1)")
        TextField {
            id: textField13
            x: 45
            y: 62
            width: 164
            height: 26
            placeholderText: qsTr("Text Field")
        }

        TextField {
            id: textField14
            x: 243
            y: 60
            width: 164
            height: 26
            placeholderText: qsTr("Text Field")
        }

        TextField {
            id: textField15
            x: 605
            y: 62
            width: 164
            height: 26
            placeholderText: qsTr("Text Field")
        }

        TextField {
            id: textField16
            x: 788
            y: 62
            width: 164
            height: 26
            placeholderText: qsTr("Text Field")
        }

        TextField {
            id: textField17
            x: 605
            y: 94
            width: 164
            height: 26
            placeholderText: qsTr("Text Field")
        }

        TextField {
            id: textField18
            x: 788
            y: 94
            width: 164
            height: 26
            placeholderText: qsTr("Text Field")
        }

        TextField {
            id: textField19
            x: 45
            y: 94
            width: 164
            height: 26
            placeholderText: qsTr("Text Field")
        }

        TextField {
            id: textField20
            x: 243
            y: 94
            width: 164
            height: 26
            placeholderText: qsTr("Text Field")
        }

        TextField {
            id: textField21
            x: 45
            y: 126
            width: 164
            height: 26
            placeholderText: qsTr("Text Field")
        }

        Text {
            id: _text5
            x: 243
            y: 30
            width: 60
            height: 24
            text: qsTr("Type")
            font.pixelSize: 16
        }

        ComboBox {
            id: comboBox4
            x: 443
            y: 62
            width: 120
            height: 26
        }

        ComboBox {
            id: comboBox5
            x: 443
            y: 94
            width: 120
            height: 26
        }

        ComboBox {
            id: comboBox6
            x: 443
            y: 126
            width: 120
            height: 26
        }

        TextField {
            id: textField22
            x: 243
            y: 126
            width: 164
            height: 26
            placeholderText: qsTr("Text Field")
        }

        TextField {
            id: textField23
            x: 605
            y: 126
            width: 164
            height: 26
            placeholderText: qsTr("Text Field")
        }

        TextField {
            id: textField24
            x: 788
            y: 126
            width: 164
            height: 26
            placeholderText: qsTr("Text Field")
        }

        Text {
            id: _text6
            x: 45
            y: 32
            width: 111
            height: 26
            text: qsTr("Name")
            font.pixelSize: 16
        }

        Text {
            id: _text7
            x: 443
            y: 32
            width: 60
            height: 24
            text: qsTr("Order")
            font.pixelSize: 16
        }

        Text {
            id: _text8
            x: 605
            y: 30
            width: 60
            height: 24
            text: qsTr("Mode")
            font.pixelSize: 16
        }

        Text {
            id: _text9
            x: 788
            y: 30
            width: 60
            height: 24
            text: qsTr("Start")
            font.pixelSize: 16
        }

        RadioButton {
            id: radioButton3
            x: 0
            y: 54
            width: 30
            height: 30
            text: ""
        }

        RadioButton {
            id: radioButton4
            x: 0
            y: 90
            width: 30
            height: 30
            text: ""
        }

        RadioButton {
            id: radioButton5
            x: 0
            y: 119
            width: 30
            height: 30
            text: ""
        }
    }

    Text {
        id: text1
        x: 449
        width: 169
        height: 48
        text: qsTr("DBC Parser")
        anchors.top: parent.top
        anchors.topMargin: 8
        font.pixelSize: 34
    }

    TextField {
        id: outputTextField
        x: 41
        y: 715
        width: 961
        height: 56
        //text: backend.output
        placeholderText: qsTr("")
    }

    states: [
        State {
            name: "clicked"
            when: button.checked

            PropertyChanges {
                target: label
                text: qsTr("Button Checked")
            }
        }
    ]
}
