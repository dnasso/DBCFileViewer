#ifndef DBCPARSER_H
#define DBCPARSER_H
#include <QObject>
#include <QUrl>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QDateTime>
#include <QFile>
#include <QTextStream>
#include <vector>
#include <string>
#include <set>

// Forward declarations
class DbcSender;

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

// Data structure for active transmission
struct ActiveTransmission {
    QString messageName;
    unsigned long messageId;
    QString taskId; // Server-assigned task ID for controlling the transmission
    int rateMs;
    bool isPaused;
    QString status; // "Active", "Paused", "Stopped"
    QString lastSent;
    int sentCount;
    QString hexData;
    QDateTime startedAt;
};

class DbcParser : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList messageModel READ messageModel NOTIFY messageModelChanged)
    Q_PROPERTY(QVariantList signalModel READ signalModel NOTIFY signalModelChanged)
    Q_PROPERTY(QString generatedCanFrame READ generatedCanFrame NOTIFY generatedCanFrameChanged)
    Q_PROPERTY(bool isConnectedToServer READ isConnectedToServer NOTIFY connectionStatusChanged)
    Q_PROPERTY(QVariantList activeTransmissions READ activeTransmissions NOTIFY activeTransmissionsChanged)
    Q_PROPERTY(bool isDbcLoaded READ isDbcLoaded NOTIFY dbcLoadedChanged)

public:
    explicit DbcParser(QObject *parent = nullptr);

    // QML accessible methods
    Q_INVOKABLE bool loadDbcFile(const QUrl &fileUrl);
    Q_INVOKABLE void selectMessage(const QString &messageName);
    Q_INVOKABLE void setShowAllSignals(bool show);
    Q_INVOKABLE void setEndian(const QString &endian);
    Q_INVOKABLE void updateSignalValue(const QString &signalName, double value);
    Q_INVOKABLE double getSignalValue(const QString &signalName);
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

    // Methods for adding/removing messages and signals
    Q_INVOKABLE bool addMessage(const QString &name, unsigned long id, int length);
    Q_INVOKABLE bool removeMessage(const QString &messageName);
    Q_INVOKABLE bool addSignal(const QString &messageName, const QString &signalName,
                               int startBit, int length, bool littleEndian,
                               double factor, double offset, double min, double max,
                               const QString &unit);
    Q_INVOKABLE bool removeSignal(const QString &messageName, const QString &signalName);
    Q_INVOKABLE bool messageExists(const QString &messageName);
    Q_INVOKABLE bool signalExists(const QString &messageName, const QString &signalName);
    Q_INVOKABLE bool isValidMessageId(unsigned long id);
    Q_INVOKABLE bool isValidSignalPosition(const QString &messageName, int startBit, int length, bool littleEndian);
    
    // Enhanced validation methods with detailed error messages
    Q_INVOKABLE QString validateMessageData(const QString &name, unsigned long id, int length);
    Q_INVOKABLE QString validateSignalData(const QString &messageName, const QString &signalName,
                                          int startBit, int length, bool littleEndian);
    Q_INVOKABLE bool checkSignalOverlap(const QString &messageName, int startBit, int length, bool littleEndian);

    Q_INVOKABLE QString prepareCanMessage(const QString &messageName, int rateMs = 0);
    Q_INVOKABLE QString getMessageHexData(const QString &messageName);
    Q_INVOKABLE QString getCurrentMessageHexData(); // Unified method for current message hex data
    Q_INVOKABLE QString getCurrentMessageBinData(); // Unified method for current message binary data
    Q_INVOKABLE unsigned long getMessageId(const QString &messageName);
    Q_INVOKABLE bool sendCanMessage(const QString &messageName, int rateMs);

    // Server connection methods
    Q_INVOKABLE bool connectToServer(const QString &address, const QString &port);
    Q_INVOKABLE void disconnectFromServer();
    Q_INVOKABLE bool isConnectedToServer() const;
    Q_INVOKABLE void setTcpClient(QObject* tcpClient);

    // Active transmissions management
    Q_INVOKABLE bool startTransmission(const QString &messageName, int rateMs);
    Q_INVOKABLE bool stopTransmission(const QString &messageName);
    Q_INVOKABLE bool pauseTransmission(const QString &messageName);
    Q_INVOKABLE bool resumeTransmission(const QString &messageName);
    Q_INVOKABLE bool stopActiveTransmission(unsigned int messageId);
    Q_INVOKABLE bool pauseActiveTransmission(unsigned int messageId);
    Q_INVOKABLE bool resumeActiveTransmission(unsigned int messageId);
    Q_INVOKABLE bool stopAllTransmissions();
    Q_INVOKABLE bool pauseAllTransmissions();
    Q_INVOKABLE bool resumeAllTransmissions();
    Q_INVOKABLE bool killAllTransmissions();
    Q_INVOKABLE bool saveActiveTransmissionsConfig(const QUrl &saveUrl);
    Q_INVOKABLE bool loadActiveTransmissionsConfig(const QUrl &loadUrl);
    Q_INVOKABLE void clearActiveTransmissions();
    Q_INVOKABLE void updateActiveTransmissions();
    Q_INVOKABLE void refreshTasksFromClient();
    
    // Helper method to add transmission without sending
    void addActiveTransmission(const QString &messageName, int rateMs, const QString &taskId = QString());
    
    // Enhanced configuration management
    Q_INVOKABLE QString getActiveTransmissionsConfigInfo(const QUrl &fileUrl);
    Q_INVOKABLE bool validateConfigFile(const QUrl &fileUrl);
    Q_INVOKABLE QStringList getConfigSummary(const QUrl &fileUrl);
    Q_INVOKABLE bool mergeActiveTransmissionsConfig(const QUrl &fileUrl, bool replaceExisting = false);
    
    // Debug methods for troubleshooting
    Q_INVOKABLE QStringList getAvailableMessages() const;
    Q_INVOKABLE QString debugLoadConfig(const QUrl &fileUrl);
    Q_INVOKABLE QString testConfigLoad(); // Simple test method

    // Property getters
    QStringList messageModel() const;
    QVariantList signalModel() const;
    QString generatedCanFrame() const;
    QVariantList activeTransmissions() const;
    bool isDbcLoaded() const;
    

signals:
    void messageModelChanged();
    void signalModelChanged();
    void generatedCanFrameChanged();
    void connectionStatusChanged();
    void messageSendStatus(const QString &messageName, bool success, const QString &statusMessage);
    void activeTransmissionsChanged();
    void transmissionStatusChanged(const QString &messageName, const QString &status);
    void dbcLoadedChanged();
    
    // Centralized notification signals
    void showNotification(const QString &message, const QString &type);
    void showError(const QString &message);
    void showWarning(const QString &message);
    void showSuccess(const QString &message);
    void showInfo(const QString &message);

private:
    void parseDBC(const QString &filePath);
    QString buildCanFrame();
    std::string trim(const std::string& s);
    
    // Helper methods for bit manipulation
    bool isBitPartOfSignal(int bitPosition, int startBit, int length, bool littleEndian);
    int getBitIndexInRawValue(int bitPosition, int startBit, bool littleEndian);
    uint64_t calculateRawValueFromBits(const QString &signalName, const QVariantList &bitValues);
    
    // Helper methods for signal validation
    int getMotorolaLsb(int msb, int length);
    std::set<int> getSignalBitPositions(int startBit, int length, bool littleEndian);

    std::vector<canMessage> messages;
    int selectedMessageIndex;
    bool showAllSignals;
    QString currentEndian;
    QString m_generatedCanFrame;
    QString originalDbcText;

    // Network communication via DbcSender
    DbcSender* dbcSender;

    // Active transmissions tracking
    QList<ActiveTransmission> m_activeTransmissions;
    
};

#endif // DBCPARSER_H
