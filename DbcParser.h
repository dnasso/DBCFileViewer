#ifndef DBCPARSER_H
#define DBCPARSER_H

#include <QObject>
#include <QString>
#include <QAbstractListModel>
#include <vector>
#include <unordered_map>

class DbcParser : public QObject {
    Q_OBJECT
public:
    explicit DbcParser(QObject *parent = nullptr);
    Q_INVOKABLE void loadDbcFile(const QString &filePath);
    Q_INVOKABLE void selectMessage(const QString &messageName);
    Q_INVOKABLE void setShowAllSignals(bool showAll);
    Q_INVOKABLE void setEndian(const QString &endian);

signals:
    void messagesUpdated();
    void signalsUpdated();
    void outputUpdated(const QString &output);

private:
    void parseDbcFile(const QString &filePath);
    void updateOutput();

    struct Signal {
        QString name;
        int startBit;
        int length;
        bool isLittleEndian;
    };

    struct Message {
        int id;
        QString name;
        std::vector<Signal> signalss;
    };

    std::unordered_map<QString, Message> messages;
    QString selectedMessage;
    bool showAllSignals = false;
    bool littleEndian = true;
};

#endif // DBCPARSER_H
