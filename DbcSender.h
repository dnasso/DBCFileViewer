#ifndef DBCSENDER_H
#define DBCSENDER_H
#include <QObject>

class DbcSender : public QObject {

public:
    Q_INVOKABLE void initiateConenction(QString Address, QString Port);
    Q_INVOKABLE void sendCANMessage(QString CANid, QString canFrame, int rate, QString bus);
    Q_INVOKABLE void stopCANMessage(QString CANid);
    Q_INVOKABLE void pauseCANMessage(QString CANid);
};
#endif // DBCSENDER_H
