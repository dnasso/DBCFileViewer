/*
Qt TCP Client Application
 */
#include <QCoreApplication>
#include <QTcpSocket>
#include <QHostAddress>
#include <QNetworkInterface>
#include <QTimer>
#include <QTextStream>
#include <QFile>
#include <QString>
#include <QDebug>
#include <iostream>
#include <fstream>
#include <string>
#include <cstring>
#include <optional>
#include <filesystem>

constexpr size_t MAXDATASIZE = 10000;

// Helper function to trim whitespace and invisible characters from string
std::string trim(const std::string& str) {
    size_t first = str.find_first_not_of(" \t\r\n\f\v");
    if (first == std::string::npos) return "";
    size_t last = str.find_last_not_of(" \t\r\n\f\v");
    return str.substr(first, last - first + 1);
}

int main(int argc, char* argv[]) {
    QCoreApplication app(argc, argv);

    if (argc != 2) {
        std::cerr << "usage: client client.conf\n";
        return 1;
    }

    // Read configuration from file
    std::optional<std::string> serverIP, serverPort;
    std::filesystem::path configFilePath(argv[1]);

    if (!std::filesystem::is_regular_file(configFilePath)) {
        std::cerr << std::format("Error opening config file: {}\n", *argv);
        return 1;
    }

    std::ifstream configFile(argv[1]);
    std::string line;
    while (std::getline(configFile, line)) {
        if (line.find("SERVER_IP=") == 0) {
            serverIP = trim(line.substr(10));
        } else if (line.find("SERVER_PORT=") == 0) {
            serverPort = trim(line.substr(12));
        }
    }
    configFile.close();

    if (!serverIP.has_value() || !serverPort.has_value()) {
        std::cerr << "Invalid config file format.\n";
        return 1;
    }

    QTcpSocket socket;
    QHostAddress address(QString::fromStdString(*serverIP));
    quint16 port = QString::fromStdString(*serverPort).toUShort();

    // Connect to server with timeout
    socket.connectToHost(address, port);
    QTimer connectTimer;
    connectTimer.setSingleShot(true);
    connectTimer.start(5000); // 5 second timeout
    bool connected = false;
    QObject::connect(&socket, &QTcpSocket::connected, [&]() {
        connected = true;
        connectTimer.stop();
    });
    QObject::connect(&connectTimer, &QTimer::timeout, [&]() {
        socket.abort();
    });
    while (!connected && connectTimer.isActive()) {
        app.processEvents();
    }
    if (!connected) {
        std::cerr << "client: failed to connect\n";
        return 2;
    }

    // Display connection information
    std::cout << std::format("client: connecting to {}\n", address.toString().toStdString());

    QTextStream in(stdin);
    QTextStream out(stdout);
    std::string userInput;
    bool niceExit = false;

    // Interactive loop for sending and receiving messages
    while (niceExit == false) {
        out << "> " << flush;
        userInput = in.readLine().toStdString();

        if (userInput.empty()) {
            continue;
        }

        if (userInput == "exit") {
            break; // Exit the loop if the user types "exit"
        }

        // Send data with timeout
        qint64 bytesWritten = socket.write(userInput.c_str(), userInput.size());
        if (bytesWritten == -1) {
            perror("send");
            break;
        }
        socket.flush();
        QTimer sendTimer;
        sendTimer.setSingleShot(true);
        sendTimer.start(5000); // 5 second timeout for write
        while (socket.bytesToWrite() > 0 && sendTimer.isActive()) {
            app.processEvents();
        }
        if (socket.bytesToWrite() > 0) {
            std::cerr << "Send timeout\n";
            break;
        }

        // Wait for response with timeout
        QTimer recvTimer;
        recvTimer.setSingleShot(true);
        recvTimer.start(5000); // 5 second timeout for read
        QByteArray response;
        while (socket.waitForReadyRead(100) && recvTimer.isActive()) {
            response += socket.readAll();
            if (response.size() >= MAXDATASIZE) break;
        }
        if (response.isEmpty() && recvTimer.isActive()) {
            std::cout << "Server closed the connection.\n";
            break;
        } else if (response.isEmpty()) {
            std::cerr << "Receive timeout\n";
            break;
        }

        std::cout << std::format("Server: {}\n", response.toStdString());
    }

    socket.close();
    return 0;
}
