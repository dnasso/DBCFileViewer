#ifndef DBCSENDER_H
#define DBCSENDER_H
#include <QObject>
#include <QTcpSocket>

class DbcSender : public QObject {

public:
    Q_INVOKABLE qint8 initiateConenction(QString Address, QString Port);
    Q_INVOKABLE qint8 sendCANMessage(QString message);
    Q_INVOKABLE void stopCANMessage(QString CANid);
    Q_INVOKABLE void pauseCANMessage(QString CANid);

private:
    QTcpSocket socket;
};
#endif // DBCSENDER_H
