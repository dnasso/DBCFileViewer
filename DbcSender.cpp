#include "DbcSender.h"
#include <QTimer>
#include <iostream>
#include <QGuiApplication>

// Send CAN Message
// Initiate Connection

qint8 DbcSender::sendCANMessage(QString message)
{
    // Undefined for now
    // sendCANMessage() called
    //QString message;
    std::string c_message = message.toStdString();
    qint64 bytesWritten = socket.write(c_message.c_str(), c_message.size());
    if (bytesWritten == -1) {
        //perror("send");
        return 1; // Failure to Write?
    }
    socket.flush(); //Non-blocking? Is this bad?
    QTimer sendTimer;
    sendTimer.setSingleShot(true);
    sendTimer.start(5000); // 5 second timeout for write
    while (socket.bytesToWrite() > 0 && sendTimer.isActive()) {
        QGuiApplication::processEvents();
    }
    if (socket.bytesToWrite() > 0) {
        std::cerr << "Send timeout\n";
        return 2; // Timeout
    }

    QTimer recvTimer;
    recvTimer.setSingleShot(true);
    recvTimer.start(5000); // 5 second timeout for read
    QByteArray response;
    // Blocking Solution - Could be bad - Fails on Windows
    while (socket.waitForReadyRead(100) && recvTimer.isActive()) {
        response += socket.readAll();
        // Do we need to check input size here?
    }
    if (response.isEmpty() && recvTimer.isActive()) {
        std::cout << "Server closed the connection.\n";
        return 0; // Is this an error?
    } else if (response.isEmpty()) {
        std::cerr << "Receive timeout\n";
        return 3;
    }

    printf("Data recieved: %s", response.toStdString().c_str());
    return 0;
}

qint8 DbcSender::initiateConenction(QString Address, QString Port)
{
    // Undefined for now
    QHostAddress address(Address);
    quint16 port = Port.toUShort();

    socket.connectToHost(address, port); // No idea if this socket is saved outside of scope - it should be right?

    QTimer connectTimer;
    connectTimer.setSingleShot(true);
    connectTimer.start(5000); // 5 second timeout
    bool connected = false;
    // TODO: Analyze these connect statements
    // "This" might be wrong:
    QObject::connect(&socket, &QTcpSocket::connected, this, [&]() {
        connected = true;
        connectTimer.stop();
    });
    // "This" might be wrong
    QObject::connect(&connectTimer, &QTimer::timeout, this, [&]() {
        socket.abort();
    });
    while (!connected && connectTimer.isActive()) {
        //app.processEvents();
        //QCoreApplication::processEvents();
        QGuiApplication::processEvents();
    }
    if (!connected) {
        //std::cerr << "client: failed to connect\n";
        std::cout << "client: failed to connect\n";
        return 1; // should do something about this
    }
    return 0; // Returns 0 if there are no issues

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
