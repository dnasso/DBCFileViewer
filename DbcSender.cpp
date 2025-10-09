#include "DbcSender.h"
#include <QTimer>
#include <iostream>
#include <QGuiApplication>

DbcSender::DbcSender(QObject *parent) : QObject(parent)
{
}

// Send CAN Message
// Initiate Connection



qint8 DbcSender::sendCANMessage(QString message)
{
    // Check if socket is connected
    if (socket.state() != QTcpSocket::ConnectedState) {
        std::cerr << "Socket not connected. Current state: " << socket.state() << std::endl;
        return 1; // Not connected
    }

    std::string c_message = "CANSEND#" + message.toStdString();
    std::cout << "Sending message: " << c_message << std::endl;
    
    qint64 bytesWritten = socket.write(c_message.c_str(), c_message.size());
    if (bytesWritten == -1) {
        std::cerr << "Failed to write to socket: " << socket.errorString().toStdString() << std::endl;
        return 1; // Failure to Write
    }
    
    if (!socket.flush()) {
        std::cerr << "Failed to flush socket" << std::endl;
        return 2; // Flush failed
    }

    // Wait for write to complete
    if (!socket.waitForBytesWritten(5000)) {
        std::cerr << "Send timeout or error: " << socket.errorString().toStdString() << std::endl;
        return 2; // Timeout
    }

    // Wait for response
    if (!socket.waitForReadyRead(5000)) {
        std::cerr << "Receive timeout or error: " << socket.errorString().toStdString() << std::endl;
        return 3; // Receive timeout
    }

    QByteArray response = socket.readAll();
    if (response.isEmpty()) {
        std::cout << "No response received" << std::endl;
        return 0; // Might be normal for some servers
    }

    std::cout << "Server response: " << response.toStdString() << std::endl; // Haven't implemented response codes
    update();
    return 0;
}

qint8 DbcSender::initiateConenction(QString Address, QString Port)
{
    // Check if already connected
    if (socket.state() == QTcpSocket::ConnectedState) {
        std::cout << "Already connected to server" << std::endl;
        return 0;
    }

    // Disconnect any existing connection
    if (socket.state() != QTcpSocket::UnconnectedState) {
        socket.disconnectFromHost();
        socket.waitForDisconnected(1000);
    }

    QHostAddress address(Address);
    quint16 port = Port.toUShort();

    std::cout << "Attempting to connect to " << Address.toStdString() << ":" << port << std::endl;

    socket.connectToHost(address, port);

    // Wait for connection with proper event loop handling
    if (socket.waitForConnected(5000)) {
        std::cout << "Successfully connected to server at " << Address.toStdString() << ":" << port << std::endl;
        return 0;
    } else {
        std::cout << "Failed to connect to server: " << socket.errorString().toStdString() << std::endl;
        return 1;
    }
}

qint8 DbcSender::stopCANMessage(QString message)
{
    // Work in progress. Do not use


    // Check if socket is connected
    if (socket.state() != QTcpSocket::ConnectedState) {
        std::cerr << "Socket not connected. Current state: " << socket.state() << std::endl;
        return 1; // Not connected
    }

    std::string c_message = "STOP#" + message.toStdString(); // Not a real command
    std::cout << "Sending message: " << c_message << std::endl;

    qint64 bytesWritten = socket.write(c_message.c_str(), c_message.size());
    if (bytesWritten == -1) {
        std::cerr << "Failed to write to socket: " << socket.errorString().toStdString() << std::endl;
        return 1; // Failure to Write
    }

    if (!socket.flush()) {
        std::cerr << "Failed to flush socket" << std::endl;
        return 2; // Flush failed
    }

    // Wait for write to complete
    if (!socket.waitForBytesWritten(5000)) {
        std::cerr << "Send timeout or error: " << socket.errorString().toStdString() << std::endl;
        return 2; // Timeout
    }

    // Wait for response
    if (!socket.waitForReadyRead(5000)) {
        std::cerr << "Receive timeout or error: " << socket.errorString().toStdString() << std::endl;
        return 3; // Receive timeout
    }

    QByteArray response = socket.readAll();
    if (response.isEmpty()) {
        std::cout << "No response received" << std::endl;
        return 0; // Might be normal for some servers
    }

    std::cout << "Server response: " << response.toStdString() << std::endl; // Haven't implemented response codes
    update();
    return 0;
}

qint8 DbcSender::pauseCANMessage(QString message)
{
    // Check if socket is connected
    if (socket.state() != QTcpSocket::ConnectedState) {
        std::cerr << "Socket not connected. Current state: " << socket.state() << std::endl;
        return 1; // Not connected
    }

    std::string c_message = "PAUSE#" +  message.toStdString();
    std::cout << "Sending message: " << c_message << std::endl;

    qint64 bytesWritten = socket.write(c_message.c_str(), c_message.size());
    if (bytesWritten == -1) {
        std::cerr << "Failed to write to socket: " << socket.errorString().toStdString() << std::endl;
        return 1; // Failure to Write
    }

    if (!socket.flush()) {
        std::cerr << "Failed to flush socket" << std::endl;
        return 2; // Flush failed
    }

    // Wait for write to complete
    if (!socket.waitForBytesWritten(5000)) {
        std::cerr << "Send timeout or error: " << socket.errorString().toStdString() << std::endl;
        return 2; // Timeout
    }

    // Wait for response
    if (!socket.waitForReadyRead(5000)) {
        std::cerr << "Receive timeout or error: " << socket.errorString().toStdString() << std::endl;
        return 3; // Receive timeout
    }

    QByteArray response = socket.readAll();
    if (response.isEmpty()) {
        std::cout << "No response received" << std::endl;
        return 0; // Might be normal for some servers
    }

    std::cout << "Server response: " << response.toStdString() << std::endl; // haven't implemented response codes
    update();
    return 0;
}

qint8 DbcSender::update()
{
    // Check if socket is connected
    if (socket.state() != QTcpSocket::ConnectedState) {
        std::cerr << "Socket not connected. Current state: " << socket.state() << std::endl;
        return 1; // Not connected
    }

    std::string c_message = "UPDATE";
    std::cout << "Sending message: " << c_message << std::endl;

    qint64 bytesWritten = socket.write(c_message.c_str(), c_message.size());
    if (bytesWritten == -1) {
        std::cerr << "Failed to write to socket: " << socket.errorString().toStdString() << std::endl;
        return 1; // Failure to Write
    }

    if (!socket.flush()) {
        std::cerr << "Failed to flush socket" << std::endl;
        return 2; // Flush failed
    }

    // Wait for write to complete
    if (!socket.waitForBytesWritten(5000)) {
        std::cerr << "Send timeout or error: " << socket.errorString().toStdString() << std::endl;
        return 2; // Timeout
    }

    // Wait for response
    if (!socket.waitForReadyRead(5000)) {
        std::cerr << "Receive timeout or error: " << socket.errorString().toStdString() << std::endl;
        return 3; // Receive timeout
    }

    QByteArray response = socket.readAll();
    if (response.isEmpty()) {
        std::cout << "No response received" << std::endl;
        return 0; // Might be normal for some servers
    }

    std::cout << "Server response: " << response.toStdString() << std::endl; // haven't implemented response codes

    // Here we are going to parse the string
    std::string response_str = response.toStdString();
    std::string current_word;
    //bool HaveWeSeenTaskID
    bool HaveWeSeenFirstLineYet;
    std::string taskID;
    std::string command;
    std::string canID;
    std::string canFrame;
    std::string rate;
    std::string bus;
    std::string status;

    QList<CAN_Entry> temp_list;

    for (int i = 0; i < response_str.length(); i++) {
        char current_char = response_str[i];
        if (current_char == '\n' and !HaveWeSeenFirstLineYet) {
            HaveWeSeenFirstLineYet = true; // We have seen the first endline. Hoorah
            current_word = ""; //Reset the word
            continue; // Restart the loop
        }
        else if (!HaveWeSeenFirstLineYet) {
            continue; //Restart the loop
        }
        else if (current_char == ':'){
            taskID = current_word;
            current_word = "";
            continue; // Restart the loop
        }
        else if (current_char == ' ' && current_word == "") {
            // Fluke reading, just loop again
            continue;
        }
        else if (current_char == ' ' && command == "") {
            command = current_word;
            current_word = "";
            continue;
        }
        else if (current_char == ' ' && bus == "") {
            bus = current_word;
            current_word = "";
            continue;
        }
        else if (current_char == '#' && canID == "") {
            canID = current_word;
            current_word = "";
            continue;
        }
        else if (current_char == ' ' && canFrame == "") {
            canFrame = current_word;
            current_word = "";
            continue;
        }
        else if (current_char == ' ' && current_word == "every") {
            current_word = "";
            continue;
        }
        else if (current_char == ' ' && rate == "") {
            // The last two characters here should be ms
            // If word was "1500ms", we save "1500".
            current_word = current_word.substr(0, current_word.length()-2);
            rate = current_word;
            current_word = "";
            continue;
        }
        else if (current_char == ' ' && status == "") {
            // Throw out filler
            current_word = "";
            continue;
        }
        else if (current_char == ')' && status == "") {
            // Check Status
            // Should have a word like "(######"
            current_word = current_word.substr(1);
            status = current_word;
            current_word = "";
            continue;
        }
        else if (current_char == '\n') {
            // Prepare for newline
            CAN_Entry next_CAN_entry;

            next_CAN_entry.taskID =  QString::fromUtf8(taskID.c_str());
            next_CAN_entry.command =  QString::fromUtf8(command.c_str());
            next_CAN_entry.canID =  QString::fromUtf8(canID.c_str());
            next_CAN_entry.canFrame = QString::fromUtf8(canFrame.c_str());
            next_CAN_entry.rate = QString::fromUtf8(rate.c_str());
            next_CAN_entry.bus = QString::fromUtf8(bus.c_str());
            next_CAN_entry.status = QString::fromUtf8(status.c_str());

            std::string taskID = "";
            std::string command = "";
            std::string canID = "";
            std::string canFrame = "";
            std::string rate = "";
            std::string bus = "";
            std::string status = "";

            temp_list.append(next_CAN_entry);
        }
        else {
            // We grab the next character here and move on with our lives
            current_word = current_word + current_char; // Just slapping letters on
        }


    }
    this->CAN_list = temp_list;
    printCANlist(); // Temporary and for testing only
    return 0;
}

void DbcSender::printCANlist() {
    std::cout << "Current Tasks";
    for (int i = 0; i < this->CAN_list.length(); i++) {
        CAN_Entry current_entry = CAN_list[i];

        std::cout << current_entry.taskID.toStdString() << ": ";
        std::cout << current_entry.command.toStdString() << " ";
        std::cout << current_entry.bus.toStdString() << " ";
        std::cout << current_entry.canID.toStdString() << "#";
        std::cout << current_entry.canFrame.toStdString() << " every ";
        std::cout << current_entry.rate.toStdString() << "ms (";
        std::cout << current_entry.status.toStdString() << ")";
    }
}

bool DbcSender::isConnected() const
{
    return socket.state() == QTcpSocket::ConnectedState;
}
