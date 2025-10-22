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
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFileInfo>
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
    QString canBus; // CAN bus interface name
};

// Data structure for past transmission history
struct PastTransmission {
    QString messageName;
    unsigned long messageId;
    QString taskId;
    int rateMs;
    QString hexData;
    QDateTime startedAt;
    QDateTime endedAt;
    QString endReason; // "Stopped", "Killed", "Error", "Completed"
    int totalSent;
    QString canBus;
    QString duration; // Formatted duration string
};

// Data structure for config file entry in file browser
struct ConfigFileEntry {
    QString fileName;
    QString filePath;
    QDateTime lastModified;
    QString description;
    int messageCount;
};

// Data structure for one-shot message history
struct OneShotMessage {
    QString messageName;
    unsigned long messageId;
    QString hexData;
    QDateTime sentAt;
    QString canBus;
};

class DbcParser : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList messageModel READ messageModel NOTIFY messageModelChanged)
    Q_PROPERTY(QVariantList signalModel READ signalModel NOTIFY signalModelChanged)
    Q_PROPERTY(QString generatedCanFrame READ generatedCanFrame NOTIFY generatedCanFrameChanged)
    Q_PROPERTY(bool isConnectedToServer READ isConnectedToServer NOTIFY connectionStatusChanged)
    Q_PROPERTY(QVariantList activeTransmissions READ activeTransmissions NOTIFY activeTransmissionsChanged)
    Q_PROPERTY(QVariantList pastTransmissions READ pastTransmissions NOTIFY pastTransmissionsChanged)
    Q_PROPERTY(QVariantList configFiles READ configFiles NOTIFY configFilesChanged)
    Q_PROPERTY(QVariantList oneShotMessages READ oneShotMessages NOTIFY oneShotMessagesChanged)
    Q_PROPERTY(bool isDbcLoaded READ isDbcLoaded NOTIFY dbcLoadedChanged)

public:
    explicit DbcParser(QObject *parent = nullptr);
    ~DbcParser(); // Destructor for proper cleanup

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
    Q_INVOKABLE QVariantMap getStructuredDiff();

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
    QString validateSignalData(const QString &messageName, const QString &signalName,
                              int startBit, int length, bool littleEndian, const QString &excludeSignal);
    Q_INVOKABLE bool checkSignalOverlap(const QString &messageName, int startBit, int length, bool littleEndian);
    Q_INVOKABLE int getNextAvailableStartBit(const QString &messageName, int length);
    Q_INVOKABLE bool isBitOccupied(const QString &messageName, int bitIndex);
    Q_INVOKABLE QString getBitOccupiedBy(const QString &messageName, int bitIndex);

    Q_INVOKABLE QString prepareCanMessage(const QString &messageName, int rateMs = 0);
    Q_INVOKABLE QString prepareCanMessage(const QString &messageName, int rateMs, const QString &canBus);
    Q_INVOKABLE QString getMessageHexData(const QString &messageName);
    Q_INVOKABLE QString getCurrentMessageHexData(); // Unified method for current message hex data
    Q_INVOKABLE QString getCurrentMessageBinData(); // Unified method for current message binary data
    Q_INVOKABLE unsigned long getMessageId(const QString &messageName);
    Q_INVOKABLE bool sendCanMessage(const QString &messageName, int rateMs);
    Q_INVOKABLE bool sendCanMessage(const QString &messageName, int rateMs, const QString &canBus);
    Q_INVOKABLE bool sendCanMessageOnce(const QString &messageName, const QString &canBus = "vcan0");

    // Server connection methods
    Q_INVOKABLE bool connectToServer(const QString &address, const QString &port);
    Q_INVOKABLE void disconnectFromServer();
    Q_INVOKABLE bool isConnectedToServer() const;
    Q_INVOKABLE void setTcpClient(QObject* tcpClient);

    // CAN interface management
    Q_INVOKABLE QStringList getAvailableCanInterfaces();

    // Active transmissions management
    Q_INVOKABLE bool startTransmission(const QString &messageName, int rateMs);
    Q_INVOKABLE bool startTransmission(const QString &messageName, int rateMs, const QString &canBus);
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
    void addActiveTransmission(const QString &messageName, const QString &taskId, int rateMs, const QString &canBus = QString());
    
    // Helper method to stop existing transmission for the same message (prevents duplicates)
    bool stopExistingTransmission(const QString &messageName);
    bool stopExistingTransmission(const QString &messageName, const QString &canBus);

    // One-shot message management
    Q_INVOKABLE bool sendRawCanMessage(const QString &messageId, const QString &hexData, const QString &canBus = "vcan0", const QString &messageName = QString());
    Q_INVOKABLE bool saveOneShotMessagesConfig(const QUrl &saveUrl);
    Q_INVOKABLE bool loadOneShotMessagesConfig(const QUrl &loadUrl);
    Q_INVOKABLE void clearOneShotMessageHistory();

    // Enhanced configuration management
    Q_INVOKABLE QString getActiveTransmissionsConfigInfo(const QUrl &fileUrl);
    Q_INVOKABLE bool validateConfigFile(const QUrl &fileUrl);
    Q_INVOKABLE QStringList getConfigSummary(const QUrl &fileUrl);
    Q_INVOKABLE bool mergeActiveTransmissionsConfig(const QUrl &fileUrl, bool replaceExisting = false);
    
    // Config file browser methods
    Q_INVOKABLE void refreshConfigFiles();
    Q_INVOKABLE void setConfigDirectory(const QUrl &directoryUrl);
    Q_INVOKABLE bool loadConfigByFileName(const QString &fileName);
    Q_INVOKABLE QString getConfigFileInfo(const QString &fileName);
    
    // Past transmissions methods
    Q_INVOKABLE void clearPastTransmissions();
    Q_INVOKABLE QVariantList getPastTransmissionsFiltered(const QString &filter = "");
    Q_INVOKABLE void exportPastTransmissions(const QUrl &saveUrl);
    
    // Debug methods for troubleshooting
    Q_INVOKABLE QStringList getAvailableMessages() const;
    Q_INVOKABLE QString debugLoadConfig(const QUrl &fileUrl);
    Q_INVOKABLE QString testConfigLoad(); // Simple test method

    // Property getters
    QStringList messageModel() const;
    QVariantList signalModel() const;
    QString generatedCanFrame() const;
    QVariantList activeTransmissions() const;
    QVariantList pastTransmissions() const;
    QVariantList configFiles() const;
    QVariantList oneShotMessages() const;
    bool isDbcLoaded() const;
    

signals:
    void messageModelChanged();
    void signalModelChanged();
    void generatedCanFrameChanged();
    void connectionStatusChanged();
    void messageSendStatus(const QString &messageName, bool success, const QString &statusMessage);
    void activeTransmissionsChanged();
    void pastTransmissionsChanged();
    void configFilesChanged();
    void oneShotMessagesChanged();
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
    
    // Helper method for past transmissions
    void addToPastTransmissions(const ActiveTransmission& transmission, const QString& endReason);

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
    
    // Past transmissions tracking
    QList<PastTransmission> m_pastTransmissions;
    
    // One-shot messages history
    QList<OneShotMessage> m_oneShotMessages;
    
    // Config file browser
    QList<ConfigFileEntry> m_configFiles;
    QString m_configDirectory;
    
};

#endif // DBCPARSER_H
