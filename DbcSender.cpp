#include "DbcSender.h"
#include <QtCore/QDateTime>
#include <QRegularExpression>
#include <iostream>
#include <algorithm>
#include <QGuiApplication>

DbcSender::DbcSender(QObject *parent) : QObject(parent), externalSocket(nullptr), usingExternalSocket(false), tcpClientRef(nullptr)
{
}

DbcSender::~DbcSender()
{
    std::cout << "DbcSender: Destructor called - cleaning up..." << std::endl;
    
    // Make sure we disconnect properly
    if (isConnected()) {
        std::cout << "DbcSender: Still connected during destruction, disconnecting..." << std::endl;
        disconnect();
    }
    
    std::cout << "DbcSender: Destructor completed" << std::endl;
}

// Send CAN Message
// Initiate Connection



qint8 DbcSender::sendCANMessage(QString message)
{
    qDebug() << "DbcSender::sendCANMessage called with message:" << message;
    
    // Check if we should route through TCP Client
    if (shouldUseTcpClient()) {
        qDebug() << "Routing CAN message through TCP Client";
        std::cout << "Routing CAN message through TCP Client" << std::endl;
        
        // Format message for TCP Client
        std::string c_message = "CANSEND#" + message.toStdString();
        QString qmlMessage = QString::fromStdString(c_message);
        
        qDebug() << "Formatted message for TCP Client:" << qmlMessage;
        std::cout << "Formatted message for TCP Client: " << qmlMessage.toStdString() << std::endl;
        
        // Send through TCP Client
        QString result;
        bool invokeSuccess = QMetaObject::invokeMethod(tcpClientRef, "sendMessage", Qt::DirectConnection,
                                  Q_RETURN_ARG(QString, result),
                                  Q_ARG(QString, qmlMessage));
        
        if (!invokeSuccess) {
            qDebug() << "Failed to invoke sendMessage on TCP Client";
            std::cout << "Failed to invoke sendMessage on TCP Client" << std::endl;
            return 1;
        }
        
        qDebug() << "TCP Client response:" << result;
        std::cout << "TCP Client response: " << result.toStdString() << std::endl;
        
        // Extract task ID from server response
        if (result.contains("task_")) {
            // Find the task ID in the response (format: "task_X")
            QRegularExpression taskRegex("task_(\\d+)");
            QRegularExpressionMatch match = taskRegex.match(result);
            if (match.hasMatch()) {
                lastTaskId = match.captured(0); // This will be "task_X"
                qDebug() << "Extracted task ID from TCP response:" << lastTaskId;
                std::cout << "Extracted task ID from TCP response: " << lastTaskId.toStdString() << std::endl;
            } else {
                lastTaskId = QString::number(QDateTime::currentMSecsSinceEpoch() % 100000);
                qDebug() << "Could not parse task ID, using temporary:" << lastTaskId;
                std::cout << "Could not parse task ID, using temporary: " << lastTaskId.toStdString() << std::endl;
            }
        } else {
            lastTaskId = QString::number(QDateTime::currentMSecsSinceEpoch() % 100000);
            qDebug() << "No task ID in TCP response, using temporary:" << lastTaskId;
            std::cout << "No task ID in TCP response, using temporary: " << lastTaskId.toStdString() << std::endl;
        }
        
        return result.contains("Failed") ? 1 : 0;
    }
    
    // Otherwise use direct socket connection
    QTcpSocket* activeSocket = getActiveSocket();
    
    // Check if socket is connected
    if (activeSocket->state() != QTcpSocket::ConnectedState) {
        std::cerr << "Socket not connected. Current state: " << activeSocket->state() << std::endl;
        return 1; // Not connected
    }

    // New format: CANSEND#canid#canmessage#rate#canbus
    // Input message format: "canid#canmessage#rate#canbus" (from DbcParser::prepareCanMessage)
    // Final format sent to server: "CANSEND#canid#canmessage#rate#canbus"
    std::string c_message = "CANSEND#" + message.toStdString();
    std::cout << "Sending message: " << c_message << std::endl;
    
    qint64 bytesWritten = activeSocket->write(c_message.c_str(), c_message.size());
    if (bytesWritten == -1) {
        std::cerr << "Failed to write to socket: " << activeSocket->errorString().toStdString() << std::endl;
        return 1; // Failure to Write
    }
    
    if (!activeSocket->flush()) {
        std::cerr << "Failed to flush socket" << std::endl;
        return 2; // Flush failed
    }

    // Wait for write to complete
    if (!activeSocket->waitForBytesWritten(5000)) {
        std::cerr << "Send timeout or error: " << activeSocket->errorString().toStdString() << std::endl;
        
        // Generate a temporary task ID for tracking even on write timeout
        lastTaskId = QString::number(QDateTime::currentMSecsSinceEpoch() % 100000);
        std::cout << "Write timeout occurred, using temporary task ID: " << lastTaskId.toStdString() << std::endl;
        
        return 2; // Timeout
    }

    // Wait for response
    if (!activeSocket->waitForReadyRead(5000)) {
        std::cerr << "Receive timeout or error: " << activeSocket->errorString().toStdString() << std::endl;
        
        // Generate a temporary task ID for tracking even on timeout
        lastTaskId = QString::number(QDateTime::currentMSecsSinceEpoch() % 100000);
        std::cout << "No response received due to timeout, using temporary task ID: " << lastTaskId.toStdString() << std::endl;
        
        return 3; // Receive timeout
    }

    QByteArray response = activeSocket->readAll();
    if (response.isEmpty()) {
        std::cout << "No response received" << std::endl;
        return 0; // Might be normal for some servers
    }

    std::string responseStr = response.toStdString();
    std::cout << "Server response: " << responseStr << std::endl;
    
    // Parse server response according to protocol
    if (responseStr.find("OK: Cansend scheduled with task ID:") == 0) {
        // Extract task ID from response
        size_t taskIdStart = responseStr.find("task ID:") + 9;
        std::string taskId = responseStr.substr(taskIdStart);
        taskId.erase(taskId.find_last_not_of(" \n\r\t") + 1); // trim whitespace
        
        // Store the task ID for later use
        lastTaskId = QString::fromStdString(taskId);
        
        std::cout << "Successfully scheduled CAN message with task ID: " << taskId << std::endl;
        return 0; // Success
    } else {
        // If no standard response, try to extract any task ID from the response
        std::cout << "Non-standard server response, attempting to parse task ID..." << std::endl;
        
        // Try to find any numeric task ID in the response
        size_t taskIdPos = responseStr.find("task");
        if (taskIdPos != std::string::npos) {
            // Look for numbers after "task"
            for (size_t i = taskIdPos; i < responseStr.length(); i++) {
                if (std::isdigit(responseStr[i])) {
                    std::string taskId;
                    while (i < responseStr.length() && std::isdigit(responseStr[i])) {
                        taskId += responseStr[i];
                        i++;
                    }
                    if (!taskId.empty()) {
                        lastTaskId = QString::fromStdString(taskId);
                        std::cout << "Extracted task ID from response: " << taskId << std::endl;
                        return 0; // Success
                    }
                    break;
                }
            }
        }
        
        // If still no task ID found, generate a temporary one for tracking
        lastTaskId = QString::number(QDateTime::currentMSecsSinceEpoch() % 100000);
        std::cout << "No task ID in response, using temporary ID: " << lastTaskId.toStdString() << std::endl;
    }
    
    if (responseStr.find("ERROR:") == 0) {
        std::cerr << "Server error: " << responseStr << std::endl;
        return 4; // Server error
    } else if (responseStr.find("cansend error") != std::string::npos) {
        std::cerr << "CAN send executable error: " << responseStr << std::endl;
        return 5; // CAN executable error
    }
    
    update();
    return 0;
}

qint8 DbcSender::sendOneShotMessage(QString message, int delayMs)
{
    qDebug() << "DbcSender::sendOneShotMessage called with message:" << message << "delay:" << delayMs;
    std::cout << "DbcSender::sendOneShotMessage called with message: " << message.toStdString() << " delay: " << delayMs << "ms" << std::endl;
    
    // Check if we should route through TCP Client
    if (shouldUseTcpClient()) {
        qDebug() << "Routing one-shot CAN message through TCP Client";
        std::cout << "Routing one-shot CAN message through TCP Client" << std::endl;
        
        // Format message for TCP Client using SEND_TASK protocol
        // Expected format: SEND_TASK#<id#data>#<delay_ms>#<interface>
        // Input message format: "canid#canmessage#rate#canbus" (from DbcParser::prepareCanMessage)
        // We'll use the input format and set delay_ms
        std::string c_message = "SEND_TASK#" + message.toStdString() + "#" + std::to_string(delayMs);
        QString qmlMessage = QString::fromStdString(c_message);
        
        qDebug() << "Formatted one-shot message for TCP Client:" << qmlMessage;
        std::cout << "Formatted one-shot message for TCP Client: " << qmlMessage.toStdString() << std::endl;
        
        // Send through TCP Client
        QString result;
        bool invokeSuccess = QMetaObject::invokeMethod(tcpClientRef, "sendMessage", Qt::DirectConnection,
                                  Q_RETURN_ARG(QString, result),
                                  Q_ARG(QString, qmlMessage));
        
        if (!invokeSuccess) {
            qDebug() << "Failed to invoke sendMessage on TCP Client for one-shot";
            std::cout << "Failed to invoke sendMessage on TCP Client for one-shot" << std::endl;
            return 1;
        }
        
        qDebug() << "TCP Client one-shot response:" << result;
        std::cout << "TCP Client one-shot response: " << result.toStdString() << std::endl;
        
        // Extract task ID from server response
        if (result.contains("task_")) {
            QRegularExpression taskRegex("task_(\\d+)");
            QRegularExpressionMatch match = taskRegex.match(result);
            if (match.hasMatch()) {
                lastTaskId = match.captured(0); // This will be "task_X"
                qDebug() << "Extracted task ID from TCP one-shot response:" << lastTaskId;
                std::cout << "Extracted task ID from TCP one-shot response: " << lastTaskId.toStdString() << std::endl;
            } else {
                lastTaskId = QString::number(QDateTime::currentMSecsSinceEpoch() % 100000);
                qDebug() << "Could not parse task ID from one-shot, using temporary:" << lastTaskId;
                std::cout << "Could not parse task ID from one-shot, using temporary: " << lastTaskId.toStdString() << std::endl;
            }
        } else {
            lastTaskId = QString::number(QDateTime::currentMSecsSinceEpoch() % 100000);
            qDebug() << "No task ID in TCP one-shot response, using temporary:" << lastTaskId;
            std::cout << "No task ID in TCP one-shot response, using temporary: " << lastTaskId.toStdString() << std::endl;
        }
        
        return result.contains("Failed") ? 1 : 0;
    }
    
    // Otherwise use direct socket connection
    QTcpSocket* activeSocket = getActiveSocket();
    
    // Check if socket is connected
    if (activeSocket->state() != QTcpSocket::ConnectedState) {
        std::cerr << "Socket not connected. Current state: " << activeSocket->state() << std::endl;
        return 1; // Not connected
    }

    // Format: SEND_TASK#<id#data>#<delay_ms>#<interface>
    // Input message format: "canid#canmessage#rate#canbus" (from DbcParser::prepareCanMessage)
    // Final format sent to server: "SEND_TASK#canid#canmessage#rate#canbus#<delay_ms>"
    std::string c_message = "SEND_TASK#" + message.toStdString() + "#" + std::to_string(delayMs);
    std::cout << "Sending one-shot message: " << c_message << std::endl;
    
    qint64 bytesWritten = activeSocket->write(c_message.c_str(), c_message.size());
    if (bytesWritten == -1) {
        std::cerr << "Failed to write one-shot to socket: " << activeSocket->errorString().toStdString() << std::endl;
        return 1; // Failure to Write
    }
    
    if (!activeSocket->flush()) {
        std::cerr << "Failed to flush one-shot socket" << std::endl;
        return 2; // Flush failed
    }

    // Wait for write to complete
    if (!activeSocket->waitForBytesWritten(5000)) {
        std::cerr << "One-shot send timeout or error: " << activeSocket->errorString().toStdString() << std::endl;
        
        // Generate a temporary task ID for tracking even on write timeout
        lastTaskId = QString::number(QDateTime::currentMSecsSinceEpoch() % 100000);
        std::cout << "One-shot write timeout occurred, using temporary task ID: " << lastTaskId.toStdString() << std::endl;
        
        return 2; // Timeout
    }

    // Wait for response
    if (!activeSocket->waitForReadyRead(5000)) {
        std::cerr << "One-shot receive timeout or error: " << activeSocket->errorString().toStdString() << std::endl;
        
        // Generate a temporary task ID for tracking even on timeout
        lastTaskId = QString::number(QDateTime::currentMSecsSinceEpoch() % 100000);
        std::cout << "No one-shot response received due to timeout, using temporary task ID: " << lastTaskId.toStdString() << std::endl;
        
        return 3; // Receive timeout
    }

    QByteArray response = activeSocket->readAll();
    if (response.isEmpty()) {
        std::cout << "No one-shot response received" << std::endl;
        return 0; // Might be normal for some servers
    }

    std::string responseStr = response.toStdString();
    std::cout << "One-shot server response: " << responseStr << std::endl;
    
    // Parse server response according to SEND_TASK protocol
    // Expected: "OK: SEND_TASK scheduled with task ID: task_5"
    if (responseStr.find("OK: SEND_TASK scheduled with task ID:") == 0) {
        // Extract task ID from response
        size_t taskIdStart = responseStr.find("task ID:") + 9;
        std::string taskId = responseStr.substr(taskIdStart);
        taskId.erase(taskId.find_last_not_of(" \n\r\t") + 1); // trim whitespace
        
        // Store the task ID for later use
        lastTaskId = QString::fromStdString(taskId);
        
        std::cout << "Successfully scheduled one-shot CAN message with task ID: " << taskId << std::endl;
        return 0; // Success
    } else {
        // If no standard response, try to extract any task ID from the response
        std::cout << "Non-standard one-shot server response, attempting to parse task ID..." << std::endl;
        
        // Try to find any numeric task ID in the response
        size_t taskIdPos = responseStr.find("task");
        if (taskIdPos != std::string::npos) {
            // Look for numbers after "task"
            for (size_t i = taskIdPos; i < responseStr.length(); i++) {
                if (std::isdigit(responseStr[i])) {
                    std::string taskId;
                    while (i < responseStr.length() && std::isdigit(responseStr[i])) {
                        taskId += responseStr[i];
                        i++;
                    }
                    if (!taskId.empty()) {
                        lastTaskId = QString::fromStdString(taskId);
                        std::cout << "Extracted task ID from one-shot response: " << taskId << std::endl;
                        return 0; // Success
                    }
                    break;
                }
            }
        }
        
        // If still no task ID found, generate a temporary one for tracking
        lastTaskId = QString::number(QDateTime::currentMSecsSinceEpoch() % 100000);
        std::cout << "No task ID in one-shot response, using temporary ID: " << lastTaskId.toStdString() << std::endl;
    }
    
    if (responseStr.find("ERROR:") == 0) {
        std::cerr << "One-shot server error: " << responseStr << std::endl;
        return 4; // Server error
    } else if (responseStr.find("cansend error") != std::string::npos) {
        std::cerr << "One-shot CAN send executable error: " << responseStr << std::endl;
        return 5; // CAN executable error
    }
    
    // Don't call update() for one-shot messages as they complete immediately
    return 0;
}

qint8 DbcSender::initiateConnection(QString Address, QString Port)
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

qint8 DbcSender::stopCANMessage(QString taskId)
{
    std::cout << "DbcSender::stopCANMessage called with taskId: " << taskId.toStdString() << std::endl;
    
    // Check if we should route through TCP Client
    if (shouldUseTcpClient()) {
        std::cout << "Routing STOP command through TCP Client" << std::endl;
        
        QString killMessage = "KILL_TASK " + taskId;
        
        // Send through TCP Client
        QString result;
        bool invokeSuccess = QMetaObject::invokeMethod(tcpClientRef, "sendMessage", Qt::DirectConnection,
                                  Q_RETURN_ARG(QString, result),
                                  Q_ARG(QString, killMessage));
        
        if (!invokeSuccess) {
            std::cout << "Failed to invoke sendMessage on TCP Client for KILL_TASK" << std::endl;
            return 1;
        }
        
        std::cout << "TCP Client KILL_TASK response: " << result.toStdString() << std::endl;
        return result.contains("Failed") ? 1 : 0;
    }
    
    // Otherwise use direct socket connection
    QTcpSocket* activeSocket = getActiveSocket();
    
    // Check if socket is connected
    if (activeSocket->state() != QTcpSocket::ConnectedState) {
        std::cerr << "Socket not connected. Current state: " << activeSocket->state() << std::endl;
        return 1; // Not connected
    }

    // Use proper KILL_TASK protocol: KILL_TASK <taskId>
    std::string c_message = "KILL_TASK " + taskId.toStdString();
    std::cout << "Sending message: " << c_message << std::endl;

    qint64 bytesWritten = activeSocket->write(c_message.c_str(), c_message.size());
    if (bytesWritten == -1) {
        std::cerr << "Failed to write to socket: " << activeSocket->errorString().toStdString() << std::endl;
        return 1; // Failure to Write
    }

    if (!activeSocket->flush()) {
        std::cerr << "Failed to flush socket" << std::endl;
        return 2; // Flush failed
    }

    // Wait for write to complete
    if (!activeSocket->waitForBytesWritten(5000)) {
        std::cerr << "Send timeout or error: " << activeSocket->errorString().toStdString() << std::endl;
        return 2; // Timeout
    }

    // Wait for response
    if (!activeSocket->waitForReadyRead(5000)) {
        std::cerr << "Receive timeout or error: " << activeSocket->errorString().toStdString() << std::endl;
        return 3; // Receive timeout
    }

    QByteArray response = activeSocket->readAll();
    if (response.isEmpty()) {
        std::cout << "No response received" << std::endl;
        return 0; // Might be normal for some servers
    }

    std::string responseStr = response.toStdString();
    std::cout << "Server response: " << responseStr << std::endl;
    
    // Parse KILL_TASK response according to protocol
    if (responseStr.find("Task ") == 0 && responseStr.find(" killed") != std::string::npos) {
        std::cout << "Task killed successfully: " << responseStr << std::endl;
        return 0; // Success
    } else if (responseStr.find("Task not found") == 0) {
        std::cerr << "Task not found: " << responseStr << std::endl;
        return 4; // Task not found
    }
    
    update();
    return 0;
}

qint8 DbcSender::pauseCANMessage(QString taskId)
{
    std::cout << "DbcSender::pauseCANMessage called with taskId: " << taskId.toStdString() << std::endl;
    
    // Check if we should route through TCP Client
    if (shouldUseTcpClient()) {
        std::cout << "Routing PAUSE command through TCP Client" << std::endl;
        
        QString pauseMessage = "PAUSE " + taskId;
        
        // Send through TCP Client
        QString result;
        bool invokeSuccess = QMetaObject::invokeMethod(tcpClientRef, "sendMessage", Qt::DirectConnection,
                                  Q_RETURN_ARG(QString, result),
                                  Q_ARG(QString, pauseMessage));
        
        if (!invokeSuccess) {
            std::cout << "Failed to invoke sendMessage on TCP Client for PAUSE" << std::endl;
            return 1;
        }
        
        std::cout << "TCP Client PAUSE response: " << result.toStdString() << std::endl;
        return result.contains("Failed") ? 1 : 0;
    }
    
    // Otherwise use direct socket connection
    QTcpSocket* activeSocket = getActiveSocket();
    
    // Check if socket is connected
    if (activeSocket->state() != QTcpSocket::ConnectedState) {
        std::cerr << "Socket not connected. Current state: " << activeSocket->state() << std::endl;
        return 1; // Not connected
    }

    std::string c_message = "PAUSE " + taskId.toStdString();
    std::cout << "Sending message: " << c_message << std::endl;

    qint64 bytesWritten = activeSocket->write(c_message.c_str(), c_message.size());
    if (bytesWritten == -1) {
        std::cerr << "Failed to write to socket: " << activeSocket->errorString().toStdString() << std::endl;
        return 1; // Failure to Write
    }

    if (!activeSocket->flush()) {
        std::cerr << "Failed to flush socket" << std::endl;
        return 2; // Flush failed
    }

    // Wait for write to complete
    if (!activeSocket->waitForBytesWritten(5000)) {
        std::cerr << "Send timeout or error: " << activeSocket->errorString().toStdString() << std::endl;
        return 2; // Timeout
    }

    // Wait for response
    if (!activeSocket->waitForReadyRead(5000)) {
        std::cerr << "Receive timeout or error: " << activeSocket->errorString().toStdString() << std::endl;
        return 3; // Receive timeout
    }

    QByteArray response = activeSocket->readAll();
    if (response.isEmpty()) {
        std::cout << "No response received" << std::endl;
        return 0; // Might be normal for some servers
    }

    std::string responseStr = response.toStdString();
    std::cout << "Server response: " << responseStr << std::endl;
    
    // Parse PAUSE response according to protocol
    if (responseStr.find("Paused ") == 0) {
        std::cout << "Task paused successfully: " << responseStr << std::endl;
        return 0; // Success
    } else if (responseStr.find("Task not found") == 0) {
        std::cerr << "Task not found: " << responseStr << std::endl;
        return 4; // Task not found
    }
    
    update();
    return 0;
}

qint8 DbcSender::resumeCANMessage(QString taskId)
{
    std::cout << "DbcSender::resumeCANMessage called with taskId: " << taskId.toStdString() << std::endl;
    
    // Check if we should route through TCP Client
    if (shouldUseTcpClient()) {
        std::cout << "Routing RESUME command through TCP Client" << std::endl;
        
        QString resumeMessage = "RESUME " + taskId;
        
        // Send through TCP Client
        QString result;
        bool invokeSuccess = QMetaObject::invokeMethod(tcpClientRef, "sendMessage", Qt::DirectConnection,
                                  Q_RETURN_ARG(QString, result),
                                  Q_ARG(QString, resumeMessage));
        
        if (!invokeSuccess) {
            std::cout << "Failed to invoke sendMessage on TCP Client for RESUME" << std::endl;
            return 1;
        }
        
        std::cout << "TCP Client RESUME response: " << result.toStdString() << std::endl;
        return result.contains("Failed") ? 1 : 0;
    }
    
    // Otherwise use direct socket connection
    QTcpSocket* activeSocket = getActiveSocket();
    
    // Check if socket is connected
    if (activeSocket->state() != QTcpSocket::ConnectedState) {
        std::cerr << "Socket not connected. Current state: " << activeSocket->state() << std::endl;
        return 1; // Not connected
    }

    std::string c_message = "RESUME " + taskId.toStdString();
    std::cout << "Sending message: " << c_message << std::endl;

    qint64 bytesWritten = activeSocket->write(c_message.c_str(), c_message.size());
    if (bytesWritten == -1) {
        std::cerr << "Failed to write to socket: " << activeSocket->errorString().toStdString() << std::endl;
        return 1; // Failure to Write
    }

    if (!activeSocket->flush()) {
        std::cerr << "Failed to flush socket" << std::endl;
        return 2; // Flush failed
    }

    // Wait for write to complete
    if (!activeSocket->waitForBytesWritten(5000)) {
        std::cerr << "Send timeout or error: " << activeSocket->errorString().toStdString() << std::endl;
        return 2; // Timeout
    }

    // Wait for response
    if (!activeSocket->waitForReadyRead(5000)) {
        std::cerr << "Receive timeout or error: " << activeSocket->errorString().toStdString() << std::endl;
        return 3; // Receive timeout
    }

    QByteArray response = activeSocket->readAll();
    if (response.isEmpty()) {
        std::cout << "No response received" << std::endl;
        return 0; // Might be normal for some servers
    }

    std::string responseStr = response.toStdString();
    std::cout << "Server response: " << responseStr << std::endl;
    
    // Parse RESUME response according to protocol
    if (responseStr.find("Resumed ") == 0) {
        std::cout << "Task resumed successfully: " << responseStr << std::endl;
        return 0; // Success
    } else if (responseStr.find("Task not found") == 0) {
        std::cerr << "Task not found: " << responseStr << std::endl;
        return 4; // Task not found
    }
    
    update();
    return 0;
}

QString DbcSender::listTasks()
{
    std::cout << "DbcSender::listTasks called" << std::endl;
    
    // Check if we should route through TCP Client
    if (shouldUseTcpClient()) {
        std::cout << "Routing LIST_TASKS command through TCP Client" << std::endl;
        
        QString listMessage = "LIST_TASKS";
        
        // Send through TCP Client
        QString result;
        bool invokeSuccess = QMetaObject::invokeMethod(tcpClientRef, "sendMessage", Qt::DirectConnection,
                                  Q_RETURN_ARG(QString, result),
                                  Q_ARG(QString, listMessage));
        
        if (!invokeSuccess) {
            std::cout << "Failed to invoke sendMessage on TCP Client for LIST_TASKS" << std::endl;
            return "Error: Failed to communicate with TCP Client";
        }
        
        std::cout << "TCP Client LIST_TASKS response: " << result.toStdString() << std::endl;
        return result;
    }
    
    // Otherwise use direct socket connection
    QTcpSocket* activeSocket = getActiveSocket();
    
    // Check if socket is connected
    if (activeSocket->state() != QTcpSocket::ConnectedState) {
        std::cerr << "Socket not connected. Current state: " << activeSocket->state() << std::endl;
        return "Error: Not connected";
    }

    std::string c_message = "LIST_TASKS";
    std::cout << "Sending message: " << c_message << std::endl;

    qint64 bytesWritten = activeSocket->write(c_message.c_str(), c_message.size());
    if (bytesWritten == -1) {
        std::cerr << "Failed to write to socket: " << activeSocket->errorString().toStdString() << std::endl;
        return "Error: Failed to write to socket";
    }

    if (!activeSocket->flush()) {
        std::cerr << "Failed to flush socket" << std::endl;
        return "Error: Failed to flush socket";
    }

    // Wait for write to complete
    if (!activeSocket->waitForBytesWritten(5000)) {
        std::cerr << "Send timeout or error: " << activeSocket->errorString().toStdString() << std::endl;
        return "Error: Send timeout";
    }

    // Wait for response
    if (!activeSocket->waitForReadyRead(5000)) {
        std::cerr << "Receive timeout or error: " << activeSocket->errorString().toStdString() << std::endl;
        return "Error: Receive timeout";
    }

    QByteArray response = activeSocket->readAll();
    if (response.isEmpty()) {
        std::cout << "No response received for LIST_TASKS" << std::endl;
        return "No tasks";
    }

    QString responseStr = QString::fromUtf8(response);
    std::cout << "LIST_TASKS Server response: " << responseStr.toStdString() << std::endl;
    
    return responseStr;
}

qint8 DbcSender::killAllTasks()
{
    std::cout << "DbcSender::killAllTasks called" << std::endl;
    
    // Check if we should route through TCP Client
    if (shouldUseTcpClient()) {
        std::cout << "Routing KILL_ALL_TASKS command through TCP Client" << std::endl;
        
        QString killAllMessage = "KILL_ALL_TASKS";
        
        // Send through TCP Client
        QString result;
        bool invokeSuccess = QMetaObject::invokeMethod(tcpClientRef, "sendMessage", Qt::DirectConnection,
                                  Q_RETURN_ARG(QString, result),
                                  Q_ARG(QString, killAllMessage));
        
        if (!invokeSuccess) {
            std::cout << "Failed to invoke sendMessage on TCP Client for KILL_ALL_TASKS" << std::endl;
            return 1;
        }
        
        std::cout << "TCP Client KILL_ALL_TASKS response: " << result.toStdString() << std::endl;
        return result.contains("Failed") ? 1 : 0;
    }
    
    // Otherwise use direct socket connection
    QTcpSocket* activeSocket = getActiveSocket();
    
    // Check if socket is connected
    if (activeSocket->state() != QTcpSocket::ConnectedState) {
        std::cerr << "Socket not connected. Current state: " << activeSocket->state() << std::endl;
        return 1; // Not connected
    }

    std::string c_message = "KILL_ALL_TASKS";
    std::cout << "Sending message: " << c_message << std::endl;

    qint64 bytesWritten = activeSocket->write(c_message.c_str(), c_message.size());
    if (bytesWritten == -1) {
        std::cerr << "Failed to write to socket: " << activeSocket->errorString().toStdString() << std::endl;
        return 1; // Failure to write
    }

    if (!activeSocket->flush()) {
        std::cerr << "Failed to flush socket" << std::endl;
        return 2; // Flush failed
    }

    // Wait for write to complete
    if (!activeSocket->waitForBytesWritten(5000)) {
        std::cerr << "Send timeout or error: " << activeSocket->errorString().toStdString() << std::endl;
        return 2; // Timeout
    }

    // Wait for response
    if (!activeSocket->waitForReadyRead(5000)) {
        std::cerr << "Receive timeout or error: " << activeSocket->errorString().toStdString() << std::endl;
        return 3; // Receive timeout
    }

    QByteArray response = activeSocket->readAll();
    if (response.isEmpty()) {
        std::cout << "No response received for KILL_ALL_TASKS" << std::endl;
        return 0; // Might be normal for some servers
    }

    std::string responseStr = response.toStdString();
    std::cout << "KILL_ALL_TASKS Server response: " << responseStr << std::endl;
    
    // Parse KILL_ALL_TASKS response according to protocol
    if (responseStr.find("All tasks killed") != std::string::npos || 
        responseStr.find("OK") != std::string::npos) {
        std::cout << "All tasks killed successfully: " << responseStr << std::endl;
        return 0; // Success
    } else if (responseStr.find("No tasks") != std::string::npos) {
        std::cout << "No tasks to kill: " << responseStr << std::endl;
        return 0; // Success (no tasks is OK)
    }
    
    return 0; // Default success
}

qint8 DbcSender::update()
{
    // Check if we should route through TCP Client
    if (shouldUseTcpClient()) {
        std::cout << "Routing UPDATE command through TCP Client" << std::endl;
        
        QString updateMessage = "UPDATE";
        
        // Send through TCP Client
        QString result;
        bool invokeSuccess = QMetaObject::invokeMethod(tcpClientRef, "sendMessage", Qt::DirectConnection,
                                  Q_RETURN_ARG(QString, result),
                                  Q_ARG(QString, updateMessage));
        
        if (!invokeSuccess) {
            std::cout << "Failed to invoke sendMessage on TCP Client for UPDATE" << std::endl;
            return 1;
        }
        
        std::cout << "TCP Client UPDATE response: " << result.toStdString() << std::endl;
        
        // Parse the response to update CAN_list
        // For TCP Client, we need to parse the result string similar to the direct socket response
        parseUpdateResponse(result);
        return result.contains("Error") ? 1 : 0;
    }
    
    // Otherwise use direct socket connection
    QTcpSocket* activeSocket = getActiveSocket();
    
    // Check if socket is connected
    if (activeSocket->state() != QTcpSocket::ConnectedState) {
        std::cerr << "Socket not connected. Current state: " << activeSocket->state() << std::endl;
        return 1; // Not connected
    }

    std::string c_message = "UPDATE";
    std::cout << "Sending message: " << c_message << std::endl;

    qint64 bytesWritten = activeSocket->write(c_message.c_str(), c_message.size());
    if (bytesWritten == -1) {
        std::cerr << "Failed to write to socket: " << activeSocket->errorString().toStdString() << std::endl;
        return 1; // Failure to Write
    }

    if (!activeSocket->flush()) {
        std::cerr << "Failed to flush socket" << std::endl;
        return 2; // Flush failed
    }

    // Wait for write to complete
    if (!activeSocket->waitForBytesWritten(5000)) {
        std::cerr << "Send timeout or error: " << activeSocket->errorString().toStdString() << std::endl;
        return 2; // Timeout
    }

    // Wait for response
    if (!activeSocket->waitForReadyRead(5000)) {
        std::cerr << "Receive timeout or error: " << activeSocket->errorString().toStdString() << std::endl;
        return 3; // Receive timeout
    }

    QByteArray response = activeSocket->readAll();
    if (response.isEmpty()) {
        std::cout << "No response received" << std::endl;
        return 0; // Might be normal for some servers
    }

    std::cout << "Server response: " << response.toStdString() << std::endl; // haven't implemented response codes

    QString responseStr = QString::fromUtf8(response);
    parseUpdateResponse(responseStr);
    return 0;
}

void DbcSender::parseUpdateResponse(const QString& responseStr)
{
    // Here we are going to parse the string
    std::string response_str = responseStr.toStdString();
    std::string current_word;
    bool HaveWeSeenFirstLineYet = false;
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

            // Reset variables for next iteration
            taskID = "";
            command = "";
            canID = "";
            canFrame = "";
            rate = "";
            bus = "";
            status = "";

            temp_list.append(next_CAN_entry);
        }
        else {
            // We grab the next character here and move on with our lives
            current_word = current_word + current_char; // Just slapping letters on
        }


    }
    this->CAN_list = temp_list;
    printCANlist(); // Temporary and for testing only
}

void DbcSender::printCANlist() {
    std::cout << "Current Tasks:" << std::endl;
    for (int i = 0; i < this->CAN_list.length(); i++) {
        CAN_Entry current_entry = CAN_list[i];

        std::cout << current_entry.taskID.toStdString() << ": ";
        std::cout << current_entry.command.toStdString() << " ";
        std::cout << current_entry.bus.toStdString() << " ";
        std::cout << current_entry.canID.toStdString() << "#";
        std::cout << current_entry.canFrame.toStdString() << " every ";
        std::cout << current_entry.rate.toStdString() << "ms (";
        std::cout << current_entry.status.toStdString() << ")" << std::endl;
    }
}

bool DbcSender::isConnected() const
{
    // First check if we should use TCP Client
    if (shouldUseTcpClient()) {
        return true; // This method already checked that TCP Client is connected
    }
    
    // Check if we have a TCP Client reference but it's not connected
    if (!tcpClientRef) {
        tcpClientRef = property("tcpClient").value<QObject*>();
    }
    if (tcpClientRef) {
        QVariant connectedProp = tcpClientRef->property("connected");
        return connectedProp.toBool();
    }
    
    // Otherwise check our own socket connection
    if (usingExternalSocket && externalSocket) {
        return externalSocket->state() == QTcpSocket::ConnectedState;
    }
    return socket.state() == QTcpSocket::ConnectedState;
}

QString DbcSender::getLastTaskId() const
{
    return lastTaskId;
}

void DbcSender::setExternalSocket(QTcpSocket* socket)
{
    externalSocket = socket;
    usingExternalSocket = (socket != nullptr);
    std::cout << "DbcSender: " << (usingExternalSocket ? "Using external socket" : "Using internal socket") << std::endl;
}

QTcpSocket* DbcSender::getActiveSocket()
{
    return usingExternalSocket ? externalSocket : &socket;
}

bool DbcSender::shouldUseTcpClient() const
{
    // Check if we have a TCP Client reference and it's connected
    if (!tcpClientRef) {
        tcpClientRef = property("tcpClient").value<QObject*>();
    }
    
    if (tcpClientRef) {
        QVariant connectedProp = tcpClientRef->property("connected");
        return connectedProp.toBool();
    }
    
    return false;
}

void DbcSender::disconnect()
{
    std::cout << "DbcSender::disconnect() called" << std::endl;
    
    // If using TCP Client, we should disconnect through it
    if (shouldUseTcpClient()) {
        std::cout << "Disconnecting through TCP Client..." << std::endl;
        
        // Try to call disconnect method on TCP Client
        if (tcpClientRef) {
            // First kill all active tasks before disconnecting
            std::cout << "Killing all tasks before disconnect..." << std::endl;
            killAllTasks();
            
            // Send disconnect message through TCP Client
            std::cout << "Sending disconnect message through TCP Client..." << std::endl;
            sendDisconnectMessage();
            
            // Try to invoke disconnect method on TCP Client
            bool invokeSuccess = QMetaObject::invokeMethod(tcpClientRef, "disconnect", Qt::DirectConnection);
            if (invokeSuccess) {
                std::cout << "Successfully called disconnect on TCP Client" << std::endl;
            } else {
                std::cout << "Failed to call disconnect on TCP Client, trying disconnectFromHost" << std::endl;
                // Try alternative method name
                QMetaObject::invokeMethod(tcpClientRef, "disconnectFromHost", Qt::DirectConnection);
            }
        }
        return;
    }
    
    // Otherwise disconnect our own socket
    QTcpSocket* activeSocket = getActiveSocket();
    if (activeSocket && activeSocket->state() == QTcpSocket::ConnectedState) {
        std::cout << "Disconnecting from server..." << std::endl;
        
        // Kill all tasks before disconnecting
        std::cout << "Killing all tasks before disconnect..." << std::endl;
        killAllTasks();
        
        // Send a proper disconnect message to server
        std::cout << "Sending disconnect message to server..." << std::endl;
        sendDisconnectMessage();
        
        // Now disconnect
        activeSocket->disconnectFromHost();
        if (activeSocket->state() != QTcpSocket::UnconnectedState) {
            activeSocket->waitForDisconnected(3000);
        }
        std::cout << "Disconnected from server" << std::endl;
    } else {
        std::cout << "Socket not connected or null" << std::endl;
    }
}

QString DbcSender::listCanInterfaces()
{
    std::cout << "DbcSender::listCanInterfaces called" << std::endl;
    
    // Check if we should route through TCP Client
    if (shouldUseTcpClient()) {
        std::cout << "Routing LIST_CAN_INTERFACES command through TCP Client" << std::endl;
        
        QString listMessage = "LIST_CAN_INTERFACES";
        
        // Send through TCP Client
        QString result;
        bool invokeSuccess = QMetaObject::invokeMethod(tcpClientRef, "sendMessage", Qt::DirectConnection,
                                  Q_RETURN_ARG(QString, result),
                                  Q_ARG(QString, listMessage));
        
        if (!invokeSuccess) {
            std::cout << "Failed to invoke sendMessage on TCP Client for LIST_CAN_INTERFACES" << std::endl;
            return "Error: Failed to communicate with TCP Client";
        }
        
        std::cout << "TCP Client LIST_CAN_INTERFACES response: " << result.toStdString() << std::endl;
        return result;
    }
    
    // Otherwise use direct socket connection
    QTcpSocket* activeSocket = getActiveSocket();
    
    // Check if socket is connected
    if (activeSocket->state() != QTcpSocket::ConnectedState) {
        std::cerr << "Socket not connected. Current state: " << activeSocket->state() << std::endl;
        return "Error: Not connected";
    }

    std::string c_message = "LIST_CAN_INTERFACES";
    std::cout << "Sending message: " << c_message << std::endl;

    qint64 bytesWritten = activeSocket->write(c_message.c_str(), c_message.size());
    if (bytesWritten == -1) {
        std::cerr << "Failed to write to socket: " << activeSocket->errorString().toStdString() << std::endl;
        return "Error: Failed to write to socket";
    }

    if (!activeSocket->flush()) {
        std::cerr << "Failed to flush socket" << std::endl;
        return "Error: Failed to flush socket";
    }

    // Wait for write to complete
    if (!activeSocket->waitForBytesWritten(5000)) {
        std::cerr << "Send timeout or error: " << activeSocket->errorString().toStdString() << std::endl;
        return "Error: Send timeout";
    }

    // Wait for response
    if (!activeSocket->waitForReadyRead(5000)) {
        std::cerr << "Receive timeout or error: " << activeSocket->errorString().toStdString() << std::endl;
        return "Error: Receive timeout";
    }

    QByteArray response = activeSocket->readAll();
    if (response.isEmpty()) {
        std::cout << "No response received for LIST_CAN_INTERFACES" << std::endl;
        return "No CAN interfaces available";
    }

    QString responseStr = QString::fromUtf8(response);
    std::cout << "LIST_CAN_INTERFACES Server response: " << responseStr.toStdString() << std::endl;
    
    return responseStr;
}

qint8 DbcSender::sendDisconnectMessage()
{
    std::cout << "DbcSender::sendDisconnectMessage called" << std::endl;
    
    // Check if we should route through TCP Client
    if (shouldUseTcpClient()) {
        std::cout << "Routing DISCONNECT command through TCP Client" << std::endl;
        
        QString disconnectMessage = "DISCONNECT";
        
        // Send through TCP Client
        QString result;
        bool invokeSuccess = QMetaObject::invokeMethod(tcpClientRef, "sendMessage", Qt::DirectConnection,
                                  Q_RETURN_ARG(QString, result),
                                  Q_ARG(QString, disconnectMessage));
        
        if (!invokeSuccess) {
            std::cout << "Failed to invoke sendMessage on TCP Client for DISCONNECT" << std::endl;
            return 1;
        }
        
        std::cout << "TCP Client DISCONNECT response: " << result.toStdString() << std::endl;
        return result.contains("Failed") ? 1 : 0;
    }
    
    // Otherwise use direct socket connection
    QTcpSocket* activeSocket = getActiveSocket();
    
    // Check if socket is connected
    if (!activeSocket || activeSocket->state() != QTcpSocket::ConnectedState) {
        std::cout << "Socket not connected, cannot send disconnect message" << std::endl;
        return 1; // Not connected
    }

    std::string c_message = "DISCONNECT";
    std::cout << "Sending disconnect message: " << c_message << std::endl;

    qint64 bytesWritten = activeSocket->write(c_message.c_str(), c_message.size());
    if (bytesWritten == -1) {
        std::cerr << "Failed to write disconnect message to socket: " << activeSocket->errorString().toStdString() << std::endl;
        return 1; // Failure to Write
    }

    if (!activeSocket->flush()) {
        std::cerr << "Failed to flush disconnect message" << std::endl;
        return 2; // Flush failed
    }

    // Wait for write to complete (shorter timeout for disconnect)
    if (!activeSocket->waitForBytesWritten(2000)) {
        std::cerr << "Disconnect message send timeout: " << activeSocket->errorString().toStdString() << std::endl;
        return 2; // Timeout
    }

    // Wait for response (shorter timeout for disconnect)
    if (!activeSocket->waitForReadyRead(2000)) {
        std::cout << "No response to disconnect message (this is normal)" << std::endl;
        return 0; // Normal - server might not respond to disconnect
    }

    QByteArray response = activeSocket->readAll();
    if (!response.isEmpty()) {
        std::string responseStr = response.toStdString();
        std::cout << "Disconnect message server response: " << responseStr << std::endl;
    }
    
    return 0; // Success
}
