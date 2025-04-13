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
    
    // New methods for signal bit visualization and editing
    Q_INVOKABLE double calculateRawValue(const QString &signalName, double physicalValue);
    Q_INVOKABLE double calculatePhysicalValue(const QString &signalName, double rawValue);
    Q_INVOKABLE bool setBit(const QString &signalName, int byteIndex, int bitIndex, bool value);
    Q_INVOKABLE bool getBit(const QString &signalName, int byteIndex, int bitIndex);
    Q_INVOKABLE QString getSignalBitMask(const QString &signalName);
    Q_INVOKABLE void updateSignalFromRawValue(const QString &signalName, uint64_t rawValue);
    Q_INVOKABLE QString formatPhysicalValueCalculation(const QString &signalName, double rawValue);
    Q_INVOKABLE void initializePreviewDialog(const QString &signalName, QVariantList &bitValues, double &rawValue);
    Q_INVOKABLE QString getFrameDataHex(const QString &signalName, double rawValue);
    Q_INVOKABLE QString getFrameDataBin(const QString &signalName, double rawValue);
    
    // New methods for updating signal parameters from UI
    Q_INVOKABLE bool updateSignalParameter(const QString &signalName, const QString &paramName, const QVariant &value);
    Q_INVOKABLE bool isBitPartOfSignal(const QString &signalName, int byteIndex, int bitIndex);

    Q_INVOKABLE QString getOriginalDbcText() const;
    Q_INVOKABLE QString getModifiedDbcText() const;
    Q_INVOKABLE bool saveModifiedDbcToFile(const QUrl &saveUrl);
    Q_INVOKABLE QStringList getDbcDiffLines();
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
    
    // Helper methods for bit manipulation
    bool isBitPartOfSignal(int bitPosition, int startBit, int length, bool littleEndian);
    int getBitIndexInRawValue(int bitPosition, int startBit, bool littleEndian);
    uint64_t calculateRawValueFromBits(const QString &signalName, const QVariantList &bitValues);

    std::vector<canMessage> messages;
    int selectedMessageIndex;
    bool showAllSignals;
    QString currentEndian;
    QString m_generatedCanFrame;
    QString originalDbcText;

    
};

#endif // DBCPARSER_H