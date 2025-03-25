

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
Rectangle {
    id: rectangle
    width: Constants.width
    height: Constants.height

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
        anchors.topMargin: 277
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

    Button {
        id: loadDBCButton
        x: 640
        y: 277
        text: qsTr("Load DBC")
        flat: false

        Connections {
            target: loadDBCButton
            function onClicked() {
                fileDialog.open()
            }
        }
    }

    Button {
        id: saveDBCButton
        x: 772
        y: 277
        text: qsTr("Save DBC")

        Connections {
            target: saveDBCButton
            function onClicked() {
                fileDialog.save()
            } //not implemented yet
        }
    }

    GroupBox {
        id: canMessagesBox
        x: 640
        y: 343
        width: 1031
        height: 251
        title: qsTr("CAN Messages")

        TextField {
            id: textField3
            x: 605
            y: 62
            width: 164
            height: 26
            placeholderText: qsTr("Text Field")
        }

        TextField {
            id: textField4
            x: 788
            y: 62
            width: 164
            height: 26
            placeholderText: qsTr("Text Field")
        }

        TextField {
            id: textField7
            x: 605
            y: 94
            width: 164
            height: 26
            placeholderText: qsTr("Text Field")
        }

        TextField {
            id: textField8
            x: 788
            y: 94
            width: 164
            height: 26
            placeholderText: qsTr("Text Field")
        }

        TextField {
            id: textField5
            x: 45
            y: 94
            width: 164
            height: 26
            placeholderText: qsTr("Text Field")
        }

        TextField {
            id: textField6
            x: 243
            y: 94
            width: 164
            height: 26
            placeholderText: qsTr("Text Field")
        }

        TextField {
            id: textField9
            x: 45
            y: 126
            width: 164
            height: 26
            placeholderText: qsTr("Text Field")
        }

        Text {
            id: canIdText
            x: 243
            y: 30
            width: 60
            height: 24
            text: qsTr("CAN ID")
            font.pixelSize: 16
        }

        ComboBox {
            id: comboBox1
            x: 443
            y: 62
            width: 120
            height: 26
        }

        ComboBox {
            id: comboBox2
            x: 443
            y: 94
            width: 120
            height: 26
        }

        ComboBox {
            id: comboBox3
            x: 443
            y: 126
            width: 120
            height: 26
        }

        TextField {
            id: textField10
            x: 243
            y: 126
            width: 164
            height: 26
            placeholderText: qsTr("Text Field")
        }

        TextField {
            id: textField11
            x: 605
            y: 126
            width: 164
            height: 26
            placeholderText: qsTr("Text Field")
        }

        TextField {
            id: textField12
            x: 788
            y: 126
            width: 164
            height: 26
            placeholderText: qsTr("Text Field")
        }

        RadioButton {
            id: radioButton3
            x: 12
            y: 332
            width: 30
            height: 30
            text: ""
        }

        RadioButton {
            id: radioButton4
            x: 12
            y: 368
            width: 30
            height: 30
            text: ""
        }

        RadioButton {
            id: radioButton5
            x: 12
            y: 397
            width: 30
            height: 30
            text: ""
        }

        Column {
            id: column
            x: 0
            y: 68
            width: 28
            height: 92

            RadioButton {
                id: radioButton1
                x: 0
                y: 94
                width: 28
                height: 28
                text: ""
                //text: qsTr("Radio Button")
            }

            RadioButton {
                id: radioButton2
                x: 0
                y: 128
                width: 28
                height: 28
                text: ""
                //text: qsTr("Radio Button")
            }
        }

        Column {
            id: column1
            x: -64
            y: -100
            width: 716
            height: 400

            Repeater {
                id: repeater

                Row {
                    id: row
                    width: 200
                    height: 400
                    visible: true

                    RadioButton {
                        id: radioButton
                        checked: true
                        width: 28
                        height: 28
                        text: ""
                        state: ""
                        //text: qsTr("Radio Button")
                    }

                    TextField {
                        id: textField
                        width: 164
                        height: 26
                        placeholderText: qsTr("Text Field")
                    }

                    TextField {
                        id: textField2
                        width: 164
                        height: 26
                        placeholderText: qsTr("Text Field")
                    }
                }
            }
        }
    }

    Text {
        id: cmNameText
        x: 688
        y: 374
        width: 57
        height: 23
        text: qsTr("Name")
        font.pixelSize: 16
    }

    Text {
        id: cmTypeText
        x: 1088
        y: 375
        width: 57
        height: 22
        text: qsTr("Type")
        font.pixelSize: 16
    }

    ComboBox {
        id: hexComboBox
        x: 950
        y: 371
        width: 90
        height: 29
        displayText: "Hex"
        model: ["Hex", "Dec"]
    }

    Text {
        id: cmDLCText
        x: 1247
        y: 375
        width: 57
        height: 22
        text: qsTr("DLC")
        font.pixelSize: 16
    }

    Text {
        id: cmCommentText
        x: 1433
        y: 375
        width: 95
        height: 22
        text: qsTr("Comment")
        font.pixelSize: 16
    }

    GroupBox {
        id: canSignalsBox
        x: 640
        y: 617
        width: 1031
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
    }

    ComboBox {
        id: comboBox9
        x: 950
        y: 281
        width: 642
        height: 56
    }

    Text {
        id: _text10
        x: 950
        y: 250
        width: 218
        height: 25
        text: qsTr("Available Message Presets:")
        font.pixelSize: 16
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
