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

    std::string c_message = message.toStdString();
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

    std::cout << "Server response: " << response.toStdString() << std::endl;
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

void DbcSender::stopCANMessage(QString CANid)
{
    // Undefined for now
    // Maybe deprecated
}

void DbcSender::pauseCANMessage(QString CANid)
{
    // Undefined for now
    // Maybe deprecated
}

bool DbcSender::isConnected() const
{
    return socket.state() == QTcpSocket::ConnectedState;
}
