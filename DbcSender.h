#ifndef DBCSENDER_H
#define DBCSENDER_H
#include <QObject>
#include <QTcpSocket>

class DbcSender : public QObject {
    Q_OBJECT

public:
    explicit DbcSender(QObject *parent = nullptr);
    Q_INVOKABLE qint8 initiateConenction(QString Address, QString Port);
    Q_INVOKABLE qint8 sendCANMessage(QString message);
    Q_INVOKABLE void stopCANMessage(QString CANid);
    Q_INVOKABLE void pauseCANMessage(QString CANid);
    Q_INVOKABLE bool isConnected() const;

private:
    QTcpSocket socket;
};
#endif // DBCSENDER_H
