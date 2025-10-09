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
    Q_INVOKABLE qint8 sendCANMessage(QString message);
    Q_INVOKABLE qint8 stopCANMessage(QString message);
    Q_INVOKABLE qint8 pauseCANMessage(QString message);
    Q_INVOKABLE qint8 update();
    Q_INVOKABLE void printCANlist(); //test
    Q_INVOKABLE bool isConnected() const;

private:
    QTcpSocket socket;
    QList<CAN_Entry> CAN_list;
};
#endif // DBCSENDER_H
