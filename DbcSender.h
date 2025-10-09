#ifndef DBCSENDER_H
#define DBCSENDER_H
#include <QObject>
#include <QTcpSocket>

struct CAN_Entry{
    // I need to store this like this
    // Placing it in the header file so I can declare a list of these
    QString taskID;
    QString command;
    QString canID;
    QString canFrame;
    QString rate;
    QString bus; //Unused? Wip
    QString status;
};

class DbcSender : public QObject {
    Q_OBJECT

public:
    explicit DbcSender(QObject *parent = nullptr);
    Q_INVOKABLE qint8 initiateConenction(QString Address, QString Port);
    Q_INVOKABLE void disconnect(); // Add disconnect method
    Q_INVOKABLE qint8 sendCANMessage(QString message);
    Q_INVOKABLE qint8 stopCANMessage(QString taskId);
    Q_INVOKABLE qint8 pauseCANMessage(QString taskId);
    Q_INVOKABLE qint8 resumeCANMessage(QString taskId);
    Q_INVOKABLE QString listTasks();
    Q_INVOKABLE qint8 killAllTasks();
    Q_INVOKABLE qint8 update();
    Q_INVOKABLE void printCANlist(); //test
    Q_INVOKABLE bool isConnected() const;
    Q_INVOKABLE QString getLastTaskId() const;
    Q_INVOKABLE void setExternalSocket(QTcpSocket* externalSocket);

private:
    QTcpSocket socket;
    QTcpSocket* externalSocket; // Pointer to external socket (from TCP Client)
    QList<CAN_Entry> CAN_list;
    QString lastTaskId; // Store the last task ID received from server
    bool usingExternalSocket; // Flag to track if using external socket
    mutable QObject* tcpClientRef; // Reference to TcpClientBackend
    
    QTcpSocket* getActiveSocket(); // Helper method to get the active socket
    bool shouldUseTcpClient() const; // Check if we should route through TCP Client
};
#endif // DBCSENDER_H
