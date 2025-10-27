/*
Qt TCP Client Backend for Qt Quick Application
 */
#include <QObject>
#include <QTcpSocket>
#include <QHostAddress>
#include <QTimer>
#include <QSettings>
#include <QDebug>
#include <QQmlEngine>
#include <QCoreApplication>
#include <iostream>
#include <string>
#include <iostream>
#include <sstream>

constexpr size_t MAXDATASIZE = 10000;

class TcpClientBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectionStatusChanged)
    Q_PROPERTY(QString lastResponse READ lastResponse NOTIFY responseReceived)

public:
    explicit TcpClientBackend(QObject* parent = nullptr) : QObject(parent) {
        qmlRegisterType<TcpClientBackend>("TcpClient", 1, 0, "TcpClientBackend");
    }

    Q_INVOKABLE bool connectToServer(const QString& ip, int port) {
        if (m_socket && m_socket->state() == QTcpSocket::ConnectedState) {
            return true; // Already connected
        }

        m_socket.reset(new QTcpSocket(this));

        QHostAddress address(ip);
        m_socket->connectToHost(address, static_cast<quint16>(port));

        // Set up connection timeout
        QTimer connectTimer;
        connectTimer.setSingleShot(true);
        connectTimer.start(5000); // 5 second timeout

        bool connected = false;

        connect(m_socket.get(), &QTcpSocket::connected, [&]() {
            connected = true;
            connectTimer.stop();
            m_connected = true;
            std::cout << "Connected to " << address.toString().toStdString() << std::endl;
            emit connectionStatusChanged();
        });

        connect(&connectTimer, &QTimer::timeout, [&]() {
            m_socket->abort();
        });

        // Wait for connection or timeout
        QEventLoop loop;
        connect(m_socket.get(), &QTcpSocket::connected, &loop, &QEventLoop::quit);
        connect(&connectTimer, &QTimer::timeout, &loop, &QEventLoop::quit);
        loop.exec();

        if (!connected) {
            std::cerr << "Failed to connect to " << ip.toStdString() << ":" << port << "\n";
            m_connected = false;
            emit connectionStatusChanged();
            return false;
        }

        // Save successful connection settings
        QSettings settings;
        settings.setValue("serverIP", ip);
        settings.setValue("serverPort", port);

        return true;
    }

    Q_INVOKABLE QString sendMessage(const QString& message) {
        std::cout << "TcpClientBackend::sendMessage called with: " << message.toStdString() << std::endl;
        
        if (!m_socket || !m_connected) {
            std::cout << "Not connected to server - m_socket: " << (m_socket ? "valid" : "null") << " m_connected: " << m_connected << std::endl;
            return "Not connected to server";
        }

        std::string msg = message.toStdString();
        // Add newline terminator if not present (many servers expect this)
        if (!msg.empty() && msg.back() != '\n') {
            msg += '\n';
        }
        
        std::cout << "Sending raw message: " << msg << std::endl;
        std::cout << "Message length: " << msg.size() << " bytes" << std::endl;
        
        qint64 bytesWritten = m_socket->write(msg.c_str(), msg.size());
        std::cout << "Bytes written: " << bytesWritten << std::endl;

        if (bytesWritten == -1) {
            return "Failed to send message";
        }

        m_socket->flush();

        // Wait for send to complete with timeout
        QTimer sendTimer;
        sendTimer.setSingleShot(true);
        sendTimer.start(5000);

        while (m_socket->bytesToWrite() > 0 && sendTimer.isActive()) {
            QCoreApplication::processEvents();
        }

        if (m_socket->bytesToWrite() > 0) {
            return "Send timeout";
        }

        // Wait for response
        QByteArray response;
        if (m_socket->waitForReadyRead(5000)) {
            response = m_socket->readAll();

            if (response.isEmpty()) {
                m_connected = false;
                emit connectionStatusChanged();
                return "Server closed connection";
            }

            m_lastResponse = QString::fromStdString(response.toStdString());
            emit responseReceived();
            std::cout << "Server: " << response.toStdString() << std::endl;
            return m_lastResponse;
        } else {
            return "Receive timeout";
        }
    }

    Q_INVOKABLE void disconnect() {
        if (m_socket) {
            m_socket->close();
            m_connected = false;
            emit connectionStatusChanged();
        }
    }

    Q_INVOKABLE QStringList getSavedSettings() {
        QSettings settings;
        QString savedIP = settings.value("serverIP", "127.0.0.1").toString();
        int savedPort = settings.value("serverPort", 8080).toInt();
        return QStringList() << savedIP << QString::number(savedPort);
    }

    bool isConnected() const {
        return m_connected;
    }

    QString lastResponse() const {
        return m_lastResponse;
    }

signals:
    void connectionStatusChanged();
    void responseReceived();

private:
    std::unique_ptr<QTcpSocket> m_socket;
    bool m_connected = false;
    QString m_lastResponse;
};

// This function can be called from main.cpp to register the type
void registerTcpClientBackend() {
    qmlRegisterType<TcpClientBackend>("TcpClient", 1, 0, "TcpClientBackend");
}

#include "Qtclient.moc"
