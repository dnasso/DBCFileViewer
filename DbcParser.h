#ifndef DBCPARSER_H
#define DBCPARSER_H

#include <QObject>
#include <QUrl>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QFile>
#include <QTextStream>
#include <vector>
#include <string>

// Data structures for CAN messages and signals (from your original code)
struct canSignal {
    std::string name;
    int startBit;
    int length;
    bool littleEndian;
    double factor;
    double offset;
    double min;
    double max;
    std::string unit;
    double value; // Added to store current signal value
};

struct canMessage {
    unsigned long id;
    std::string name;
    int length;
    std::vector<canSignal> signalList; // Renamed from 'signals' to avoid Qt keyword conflict
};

class DbcParser : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList messageModel READ messageModel NOTIFY messageModelChanged)
    Q_PROPERTY(QVariantList signalModel READ signalModel NOTIFY signalModelChanged)
    Q_PROPERTY(QString generatedCanFrame READ generatedCanFrame NOTIFY generatedCanFrameChanged)

public:
    explicit DbcParser(QObject *parent = nullptr);

    // QML accessible methods
    Q_INVOKABLE bool loadDbcFile(const QUrl &fileUrl);
    Q_INVOKABLE void selectMessage(const QString &messageName);
    Q_INVOKABLE void setShowAllSignals(bool show);
    Q_INVOKABLE void setEndian(const QString &endian);
    Q_INVOKABLE void updateSignalValue(const QString &signalName, double value);
    Q_INVOKABLE QString generateCanFrame();

    // Property getters
    QStringList messageModel() const;
    QVariantList signalModel() const;
    QString generatedCanFrame() const;

signals:
    void messageModelChanged();
    void signalModelChanged();
    void generatedCanFrameChanged();

private:
    void parseDBC(const QString &filePath);
    QString buildCanFrame();
    std::string trim(const std::string& s);

    std::vector<canMessage> messages;
    int selectedMessageIndex;
    bool showAllSignals;
    QString currentEndian;
    QString m_generatedCanFrame;
};

#endif // DBCPARSER_H