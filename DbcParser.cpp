#include "DbcParser.h"
#include "DbcSender.h"
#include <QFile>
#include <QTextStream>
#include <QRegularExpression>
#include <QFileInfo>
#include <QDir>
#include <QDebug>
#include <QTimer>
#include <QDateTime>
#include <QThread>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QJsonArray>
#include <QtCore/QCoreApplication>
#include <sstream>
#include <iostream>
#include <iomanip>
#include <bitset>
#include <cmath>
#include <set>
#include <algorithm>

DbcParser::DbcParser(QObject *parent)
    : QObject(parent), selectedMessageIndex(-1), showAllSignals(false), currentEndian("little"), dbcSender(nullptr)
{
    // Initialize with some default values
    m_generatedCanFrame = "";
    
    // Initialize DbcSender
    dbcSender = new DbcSender(this);
    
    // Note: Connection to CAN receiver is now handled through the GUI TCP Client tab
    qDebug() << "DbcParser: Initialized - use TCP Client tab to connect to server";
}

DbcParser::~DbcParser()
{
    qDebug() << "DbcParser: Destructor called - cleaning up...";
    
    // Ensure proper cleanup when the application closes
    if (dbcSender) {
        // Stop all active transmissions
        if (!m_activeTransmissions.isEmpty()) {
            qDebug() << "DbcParser: Stopping all active transmissions during cleanup";
            killAllTransmissions();
        }
        
        // Disconnect from server
        if (dbcSender->isConnected()) {
            qDebug() << "DbcParser: Disconnecting from server during cleanup";
            dbcSender->disconnect();
        }
        
        // The DbcSender will be deleted automatically since it's a child of this object
        qDebug() << "DbcParser: DbcSender cleanup completed";
    }
    
    qDebug() << "DbcParser: Destructor completed";
}

bool DbcParser::loadDbcFile(const QUrl &fileUrl)
{
    QString filePath = fileUrl.toLocalFile();
    if (filePath.isEmpty()) {
        emit showError("Invalid file path");
        qWarning() << "Empty file path";
        return false;
    }

    QFileInfo fileInfo(filePath);
    if (!fileInfo.exists()) {
        emit showError("DBC file does not exist: " + fileInfo.fileName());
        qWarning() << "File does not exist:" << filePath;
        return false;
    }

    // Clear existing data
    messages.clear();
    selectedMessageIndex = -1;
    m_generatedCanFrame.clear();

    // Parse the DBC file
    // Load and store original content
    QFile originalFile(filePath);
    if (originalFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        originalDbcText = QTextStream(&originalFile).readAll();
        originalFile.close();
    }

    // Parse the DBC content
    parseDBC(filePath);


    // Notify QML that our models have changed
    emit messageModelChanged();
    emit signalModelChanged();
    emit generatedCanFrameChanged();
    emit dbcLoadedChanged();

    return true;
}

void DbcParser::parseDBC(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "Could not open file:" << filePath;
        return;
    }

    QTextStream in(&file);
    QString line;
    canMessage *currentMessage = nullptr;

    while (!in.atEnd()) {
        line = in.readLine();

        // Check if this line starts a new CAN message.
        if (line.startsWith("BO_")) {
            canMessage msg;
            QStringList parts = line.split(" ", Qt::SkipEmptyParts);
            
            if (parts.size() >= 4) {
                // Format: BO_ 123 MESSAGE_NAME: 8 SENDER
                msg.id = parts[1].toULong();
                
                // Remove the colon from the message name if present
                QString msgName = parts[2];
                if (msgName.endsWith(":")) {
                    msgName.chop(1);
                }
                msg.name = msgName.toStdString();
                
                // Get message length
                int colonIndex = line.indexOf(':');
                if (colonIndex != -1) {
                    QStringList afterColon = line.mid(colonIndex + 1).split(" ", Qt::SkipEmptyParts);
                    if (!afterColon.isEmpty()) {
                        msg.length = afterColon[0].toInt();
                    }
                }
                
                msg.signalList.clear();
                messages.push_back(msg);
                currentMessage = &messages.back();
            }
        }
        // Look for signal definitions
        else if (line.contains(" SG_")) {
            if (!currentMessage) {
                qWarning() << "Signal found but no message to attach to";
                continue;
            }

            canSignal sig;
            sig.value = 0; // Initialize value to 0

            // Using regex to parse the signal line
            QRegularExpression re(" SG_ ([^ ]+) : (\\d+)\\|(\\d+)@([01])([+-]) \\(([^,]+),([^\\)]+)\\) \\[([^\\|]+)\\|([^\\]]+)\\] \"([^\"]*)\"");
            QRegularExpressionMatch match = re.match(line);
            
            if (match.hasMatch()) {
                sig.name = match.captured(1).toStdString();
                sig.startBit = match.captured(2).toInt();
                sig.length = match.captured(3).toInt();
                sig.littleEndian = (match.captured(4) == "1");
                
                try {
                    sig.factor = match.captured(6).toDouble();
                    sig.offset = match.captured(7).toDouble();
                    sig.min = match.captured(8).toDouble();
                    sig.max = match.captured(9).toDouble();
                } catch (const std::exception& e) {
                    qWarning() << "Error parsing numeric values in signal" << QString::fromStdString(sig.name);
                    sig.factor = 1.0;
                    sig.offset = 0.0;
                    sig.min = 0.0;
                    sig.max = 0.0;
                }
                
                sig.unit = match.captured(10).toStdString();
                
                currentMessage->signalList.push_back(sig);
            } else {
                // Fallback parsing for non-standard format
                QStringList parts = line.trimmed().split(" ", Qt::SkipEmptyParts);
                if (parts.size() >= 3 && parts[0] == "SG_") {
                    sig.name = parts[1].toStdString();
                    
                    // Try to extract bit position info
                    for (int i = 2; i < parts.size(); i++) {
                        if (parts[i].contains("|") && parts[i].contains("@")) {
                            QStringList bitInfo = parts[i].split("@");
                            if (bitInfo.size() >= 2) {
                                QStringList startLen = bitInfo[0].split("|");
                                if (startLen.size() >= 2) {
                                    sig.startBit = startLen[0].toInt();
                                    sig.length = startLen[1].toInt();
                                }
                                sig.littleEndian = bitInfo[1].startsWith("1");
                            }
                            break;
                        }
                    }
                    
                    // Try to extract factor and offset
                    for (int i = 0; i < parts.size(); i++) {
                        if (parts[i].startsWith("(") && parts[i].endsWith(")")) {
                            QString factorOffset = parts[i].mid(1, parts[i].length() - 2);
                            QStringList values = factorOffset.split(",");
                            if (values.size() >= 2) {
                                sig.factor = values[0].toDouble();
                                sig.offset = values[1].toDouble();
                            }
                            break;
                        }
                    }
                    
                    // Try to extract min and max
                    for (int i = 0; i < parts.size(); i++) {
                        if (parts[i].startsWith("[") && parts[i].endsWith("]")) {
                            QString minMax = parts[i].mid(1, parts[i].length() - 2);
                            QStringList values = minMax.split("|");
                            if (values.size() >= 2) {
                                sig.min = values[0].toDouble();
                                sig.max = values[1].toDouble();
                            }
                            break;
                        }
                    }
                    
                    // Try to extract unit
                    for (int i = 0; i < parts.size(); i++) {
                        if (parts[i].startsWith("\"") && parts[i].endsWith("\"")) {
                            sig.unit = parts[i].mid(1, parts[i].length() - 2).toStdString();
                            break;
                        }
                    }
                    
                    currentMessage->signalList.push_back(sig);
                }
            }
        }
    }
    
    file.close();
}

QStringList DbcParser::messageModel() const
{
    QStringList result;
    for (const auto& msg : messages) {
        result.append(QString("%1 (0x%2)").arg(QString::fromStdString(msg.name))
                                          .arg(msg.id, 0, 16));
    }
    return result;
}

QVariantList DbcParser::signalModel() const
{
    QVariantList result;
    
    if (selectedMessageIndex >= 0 && selectedMessageIndex < static_cast<int>(messages.size())) {
        const auto& msg = messages[selectedMessageIndex];
        
        for (const auto& sig : msg.signalList) {
            QVariantMap signalData;
            signalData["name"] = QString::fromStdString(sig.name);
            signalData["startBit"] = sig.startBit;
            signalData["length"] = sig.length;
            signalData["littleEndian"] = sig.littleEndian;
            signalData["factor"] = sig.factor;
            signalData["offset"] = sig.offset;
            signalData["min"] = sig.min;
            signalData["max"] = sig.max;
            signalData["unit"] = QString::fromStdString(sig.unit);
            signalData["value"] = sig.value;
            
            result.append(signalData);
        }
    }
    
    return result;
}

void DbcParser::selectMessage(const QString &messageName)
{
    // Extract the message name without the ID part
    int parenthesisPos = messageName.indexOf(" (");
    QString name = parenthesisPos > 0 ? messageName.left(parenthesisPos) : messageName;
    
    for (size_t i = 0; i < messages.size(); i++) {
        if (QString::fromStdString(messages[i].name) == name) {
            selectedMessageIndex = static_cast<int>(i);
            emit signalModelChanged();
            emit generatedCanFrameChanged();
            return;
        }
    }
    
    // If we get here, the message wasn't found
    selectedMessageIndex = -1;
    emit signalModelChanged();
    emit generatedCanFrameChanged();
}

void DbcParser::setShowAllSignals(bool show)
{
    showAllSignals = show;
    emit signalModelChanged();
}

void DbcParser::setEndian(const QString &endian)
{
    currentEndian = endian.toLower();
    emit generatedCanFrameChanged();
}

void DbcParser::updateSignalValue(const QString &signalName, double value)
{
    if (selectedMessageIndex >= 0 && selectedMessageIndex < static_cast<int>(messages.size())) {
        auto& msg = messages[selectedMessageIndex];
        
        for (auto& sig : msg.signalList) {
            if (QString::fromStdString(sig.name) == signalName) {
                sig.value = value;
                emit generatedCanFrameChanged();
                emit signalModelChanged();
                return;
            }
        }
    }
}

double DbcParser::getSignalValue(const QString &signalName)
{
    if (selectedMessageIndex >= 0 && selectedMessageIndex < static_cast<int>(messages.size())) {
        auto& msg = messages[selectedMessageIndex];
        
        for (const auto& sig : msg.signalList) {
            if (QString::fromStdString(sig.name) == signalName) {
                return sig.value;
            }
        }
    }
    return 0.0; // Default value if signal not found
}

QString DbcParser::generateCanFrame()
{
    if (selectedMessageIndex < 0 || selectedMessageIndex >= static_cast<int>(messages.size())) {
        return QString();
    }
    
    return buildCanFrame();
}

QString DbcParser::generatedCanFrame() const
{
    if (selectedMessageIndex < 0 || selectedMessageIndex >= static_cast<int>(messages.size())) {
        return QString();
    }
    
    const auto& msg = messages[selectedMessageIndex];
    QString frameInfo = QString("ID: 0x%1 (%2)  Length: %3 bytes")
                               .arg(msg.id, 0, 16)
                               .arg(QString::fromStdString(msg.name))
                               .arg(msg.length);
    
    // Return the current frame info if we have one
    if (!m_generatedCanFrame.isEmpty()) {
        return frameInfo + "\n" + m_generatedCanFrame;
    }
    
    return frameInfo;
}

QString DbcParser::buildCanFrame()
{
    const auto& msg = messages[selectedMessageIndex];
    
    // Create a buffer of zeros for the CAN frame data
    std::vector<uint8_t> frameData(msg.length, 0);
    
    // For each signal, pack its value into the frame
    for (const auto& sig : msg.signalList) {
        // Convert the physical value to raw value
        double rawValue = (sig.value - sig.offset) / sig.factor;
        
        // Clamp to min/max if defined
        if (sig.min != sig.max) {
            rawValue = std::max(sig.min, std::min(rawValue, sig.max));
        }
        
        // Round to integer
        uint64_t intValue = static_cast<uint64_t>(std::round(rawValue));
        
        // Apply bit mask based on signal length
        uint64_t mask = (1ULL << sig.length) - 1;
        intValue &= mask;
        
        // Pack the value into the frame based on endianness
        int startBit = sig.startBit;
        
        if (sig.littleEndian) {
            // Little endian (Intel format)
            for (int i = 0; i < sig.length; i++) {
                int byteIndex = startBit / 8;
                int bitIndex = startBit % 8;
                
                if (byteIndex < msg.length) {
                    // Set or clear bit
                    if (intValue & (1ULL << i)) {
                        frameData[byteIndex] |= (1 << bitIndex);
                    } else {
                        frameData[byteIndex] &= ~(1 << bitIndex);
                    }
                }
                
                startBit++;
            }
        } else {
            // Big endian (Motorola format)
            int msb = startBit;
            for (int i = 0; i < sig.length; i++) {
                int byteIndex = msb / 8;
                int bitIndex = 7 - (msb % 8);
                
                if (byteIndex < msg.length) {
                    // Set or clear bit
                    if (intValue & (1ULL << (sig.length - 1 - i))) {
                        frameData[byteIndex] |= (1 << bitIndex);
                    } else {
                        frameData[byteIndex] &= ~(1 << bitIndex);
                    }
                }
                
                // Decrement for Motorola format
                msb--;
                if (msb < 0) break;
            }
        }
    }
    
    // Format the frame data as a hex string
    std::stringstream ss;
    ss << "Data: ";
    for (size_t i = 0; i < frameData.size(); i++) {
        ss << std::hex << std::uppercase << std::setw(2) << std::setfill('0') << static_cast<int>(frameData[i]);
        if (i < frameData.size() - 1) {
            ss << " ";
        }
    }
    
    m_generatedCanFrame = QString::fromStdString(ss.str());
    return m_generatedCanFrame;
}

std::string DbcParser::trim(const std::string& s) {
    size_t start = s.find_first_not_of(" \t");
    size_t end = s.find_last_not_of(" \t");
    if (start == std::string::npos) return "";
    return s.substr(start, end - start + 1);
}

// New methods for signal bit visualization and editing

double DbcParser::calculateRawValue(const QString &signalName, double physicalValue)
{
    if (selectedMessageIndex < 0 || selectedMessageIndex >= static_cast<int>(messages.size())) {
        return 0.0;
    }
    
    auto& msg = messages[selectedMessageIndex];
    
    for (auto& sig : msg.signalList) {
        if (QString::fromStdString(sig.name) == signalName) {
            // Convert from physical value to raw value
            double rawValue = (physicalValue - sig.offset) / sig.factor;
            return rawValue;
        }
    }
    
    return 0.0;
}

double DbcParser::calculatePhysicalValue(const QString &signalName, double rawValue)
{
    if (selectedMessageIndex < 0 || selectedMessageIndex >= static_cast<int>(messages.size())) {
        return 0.0;
    }
    
    auto& msg = messages[selectedMessageIndex];
    
    for (auto& sig : msg.signalList) {
        if (QString::fromStdString(sig.name) == signalName) {
            // Convert from raw value to physical value
            double physicalValue = (rawValue * sig.factor) + sig.offset;
            return physicalValue;
        }
    }
    
    return 0.0;
}

bool DbcParser::setBit(const QString &signalName, int byteIndex, int bitIndex, bool value)
{
    if (selectedMessageIndex < 0 || selectedMessageIndex >= static_cast<int>(messages.size())) {
        return false;
    }
    
    auto& msg = messages[selectedMessageIndex];
    
    for (auto& sig : msg.signalList) {
        if (QString::fromStdString(sig.name) == signalName) {
            // Get the current raw value
            double rawValue = calculateRawValue(signalName, sig.value);
            uint64_t intValue = static_cast<uint64_t>(std::round(rawValue));
            
            // Find the bit position in the overall signal
            int bitPosition = byteIndex * 8 + bitIndex;
            
            // Check if this bit is part of the signal
            if (!isBitPartOfSignal(bitPosition, sig.startBit, sig.length, sig.littleEndian)) {
                return false;
            }
            
            // Calculate which bit in the raw value needs to be changed
            int rawBitIndex = getBitIndexInRawValue(bitPosition, sig.startBit, sig.littleEndian);
            
            // Set or clear the bit
            if (value) {
                intValue |= (1ULL << rawBitIndex);
            } else {
                intValue &= ~(1ULL << rawBitIndex);
            }
            
            // Update the signal value
            double newPhysicalValue = calculatePhysicalValue(signalName, intValue);
            sig.value = newPhysicalValue;
            
            // Notify QML that the signal value has changed
            emit signalModelChanged();
            emit generatedCanFrameChanged();
            
            return true;
        }
    }
    
    return false;
}

bool DbcParser::getBit(const QString &signalName, int byteIndex, int bitIndex)
{
    if (selectedMessageIndex < 0 || selectedMessageIndex >= static_cast<int>(messages.size())) {
        return false;
    }
    
    auto& msg = messages[selectedMessageIndex];
    
    for (auto& sig : msg.signalList) {
        if (QString::fromStdString(sig.name) == signalName) {
            // Get the current raw value
            double rawValue = calculateRawValue(signalName, sig.value);
            uint64_t intValue = static_cast<uint64_t>(std::round(rawValue));
            
            // Find the bit position in the overall signal
            int bitPosition = byteIndex * 8 + bitIndex;
            
            // Check if this bit is part of the signal
            if (!isBitPartOfSignal(bitPosition, sig.startBit, sig.length, sig.littleEndian)) {
                return false;
            }
            
            // Calculate which bit in the raw value needs to be checked
            int rawBitIndex = getBitIndexInRawValue(bitPosition, sig.startBit, sig.littleEndian);
            
            // Return the bit value
            return (intValue & (1ULL << rawBitIndex)) != 0;
        }
    }
    
    return false;
}

QString DbcParser::getSignalBitMask(const QString &signalName)
{
    if (selectedMessageIndex < 0 || selectedMessageIndex >= static_cast<int>(messages.size())) {
        return QString();
    }
    
    auto& msg = messages[selectedMessageIndex];
    
    for (auto& sig : msg.signalList) {
        if (QString::fromStdString(sig.name) == signalName) {
            QString mask;
            
            // Generate a mask string where '1' indicates bits that are part of this signal
            for (int byteIndex = 7; byteIndex >= 0; byteIndex--) {
                for (int bitIndex = 7; bitIndex >= 0; bitIndex--) {
                    int bitPosition = byteIndex * 8 + bitIndex;
                    if (isBitPartOfSignal(bitPosition, sig.startBit, sig.length, sig.littleEndian)) {
                        mask += "1";
                    } else {
                        mask += "0";
                    }
                }
            }
            
            return mask;
        }
    }
    
    return QString();
}

void DbcParser::updateSignalFromRawValue(const QString &signalName, uint64_t rawValue)
{
    if (selectedMessageIndex < 0 || selectedMessageIndex >= static_cast<int>(messages.size())) {
        return;
    }
    
    auto& msg = messages[selectedMessageIndex];
    
    for (auto& sig : msg.signalList) {
        if (QString::fromStdString(sig.name) == signalName) {
            // Convert raw value to physical value
            double physicalValue = calculatePhysicalValue(signalName, rawValue);
            
            // Update the signal value
            sig.value = physicalValue;
            
            // Notify QML that the signal value has changed
            emit signalModelChanged();
            emit generatedCanFrameChanged();
            
            return;
        }
    }
}
QString DbcParser::formatPhysicalValueCalculation(const QString &signalName, double rawValue)
{
    if (selectedMessageIndex < 0 || selectedMessageIndex >= static_cast<int>(messages.size())) {
        return QString();
    }
    
    auto& msg = messages[selectedMessageIndex];
    
    for (auto& sig : msg.signalList) {
        if (QString::fromStdString(sig.name) == signalName) {
            // Format the calculation
            double physicalValue = calculatePhysicalValue(signalName, rawValue);
            
            // Format with hex and decimal
            QString hexDisplay = QString("0x%1").arg(static_cast<uint64_t>(rawValue), 0, 16).toUpper();
            
            QString result = QString("Data = %1 = %2\n").arg(hexDisplay).arg(static_cast<uint64_t>(rawValue));
            
            // Add formula with units similar to the second screenshot
            result += QString("Physical value = %1 * %2 + %3 = %4 %5")
                         .arg(sig.factor)
                         .arg(static_cast<uint64_t>(rawValue))
                         .arg(sig.offset)
                         .arg(physicalValue)
                         .arg(QString::fromStdString(sig.unit));
            
            return result;
        }
    }
    
    return QString();
}

void DbcParser::initializePreviewDialog(const QString &signalName, QVariantList &bitValues, double &rawValue)
{
    if (selectedMessageIndex < 0 || selectedMessageIndex >= static_cast<int>(messages.size())) {
        return;
    }
    
    auto& msg = messages[selectedMessageIndex];
    
    for (auto& sig : msg.signalList) {
        if (QString::fromStdString(sig.name) == signalName) {
            // Calculate raw value
            rawValue = calculateRawValue(signalName, sig.value);
            
            // Initialize bit values array
            bitValues.clear();
            for (int byteIndex = 7; byteIndex >= 0; byteIndex--) {
                for (int bitIndex = 7; bitIndex >= 0; bitIndex--) {
                    QVariantMap bitInfo;
                    int bitPosition = byteIndex * 8 + bitIndex;
                    bool isPartOfSignal = isBitPartOfSignal(bitPosition, sig.startBit, sig.length, sig.littleEndian);
                    bool isSet = false;
                    
                    if (isPartOfSignal) {
                        int rawBitIndex = getBitIndexInRawValue(bitPosition, sig.startBit, sig.littleEndian);
                        isSet = (static_cast<uint64_t>(rawValue) & (1ULL << rawBitIndex)) != 0;
                    }
                    
                    bitInfo["byteIndex"] = byteIndex;
                    bitInfo["bitIndex"] = bitIndex;
                    bitInfo["isPartOfSignal"] = isPartOfSignal;
                    bitInfo["isSet"] = isSet;
                    
                    bitValues.append(bitInfo);
                }
            }
            
            return;
        }
    }
}

uint64_t DbcParser::calculateRawValueFromBits(const QString &signalName, const QVariantList &bitValues)
{
    if (selectedMessageIndex < 0 || selectedMessageIndex >= static_cast<int>(messages.size())) {
        return 0;
    }
    
    auto& msg = messages[selectedMessageIndex];
    
    for (auto& sig : msg.signalList) {
        if (QString::fromStdString(sig.name) == signalName) {
            uint64_t rawValue = 0;
            
            for (const QVariant &bitInfo : bitValues) {
                QVariantMap bitMap = bitInfo.toMap();
                
                if (bitMap["isPartOfSignal"].toBool() && bitMap["isSet"].toBool()) {
                    int byteIndex = bitMap["byteIndex"].toInt();
                    int bitIndex = bitMap["bitIndex"].toInt();
                    int bitPosition = byteIndex * 8 + bitIndex;
                    int rawBitIndex = getBitIndexInRawValue(bitPosition, sig.startBit, sig.littleEndian);
                    
                    rawValue |= (1ULL << rawBitIndex);
                }
            }
            
            return rawValue;
        }
    }
    
    return 0;
}

// Add these implementations to your DbcParser.cpp file:

// NEW FUNCTION: Update signal parameters (factor, offset, etc.)
bool DbcParser::updateSignalParameter(const QString &signalName, const QString &paramName, const QVariant &value)
{
    if (selectedMessageIndex < 0 || selectedMessageIndex >= static_cast<int>(messages.size())) {
        return false;
    }
    
    auto& msg = messages[selectedMessageIndex];
    
    for (auto& sig : msg.signalList) {
        if (QString::fromStdString(sig.name) == signalName) {
            // Store original values for validation
            int originalStartBit = sig.startBit;
            int originalLength = sig.length;
            
            // Prepare new values for validation
            int newStartBit = originalStartBit;
            int newLength = originalLength;
            
            // Update the specified parameter with validation
            if (paramName == "startBit") {
                newStartBit = value.toInt();
                // Basic bounds check
                if (newStartBit < 0 || newStartBit > 63) {
                    qDebug() << "updateSignalParameter: Invalid start bit" << newStartBit << "for signal" << signalName;
                    return false;
                }
            }
            else if (paramName == "length") {
                newLength = value.toInt();
                // Basic bounds check
                if (newLength < 1 || newLength > 64) {
                    qDebug() << "updateSignalParameter: Invalid length" << newLength << "for signal" << signalName;
                    return false;
                }
            }
            else if (paramName == "factor") {
                sig.factor = value.toDouble();
                // Notify QML that the signal model has changed
                emit signalModelChanged();
                emit generatedCanFrameChanged();
                return true;
            }
            else if (paramName == "offset") {
                sig.offset = value.toDouble();
                // Notify QML that the signal model has changed
                emit signalModelChanged();
                emit generatedCanFrameChanged();
                return true;
            }
            else if (paramName == "min") {
                sig.min = value.toDouble();
                // Notify QML that the signal model has changed
                emit signalModelChanged();
                emit generatedCanFrameChanged();
                return true;
            }
            else if (paramName == "max") {
                sig.max = value.toDouble();
                // Notify QML that the signal model has changed
                emit signalModelChanged();
                emit generatedCanFrameChanged();
                return true;
            }
            else if (paramName == "unit") {
                sig.unit = value.toString().toStdString();
                // Notify QML that the signal model has changed
                emit signalModelChanged();
                emit generatedCanFrameChanged();
                return true;
            }
            else if (paramName == "littleEndian") {
                sig.littleEndian = value.toBool();
                // Notify QML that the signal model has changed
                emit signalModelChanged();
                emit generatedCanFrameChanged();
                return true;
            }
            else {
                // Unknown parameter
                return false;
            }
            
            // For startBit and length changes, validate against overlaps
            if (paramName == "startBit" || paramName == "length") {
                // Check if new start bit + length exceeds 64 bits
                if (newStartBit + newLength > 64) {
                    qDebug() << "updateSignalParameter: Signal" << signalName << "would exceed 64 bits with start bit" << newStartBit << "and length" << newLength;
                    return false;
                }
                
                // Validate against overlaps with other signals (exclude the current signal being edited)
                QString validationError = validateSignalData(
                    QString::fromStdString(msg.name),
                    signalName,
                    newStartBit,
                    newLength,
                    sig.littleEndian,
                    signalName  // Exclude the current signal from validation
                );
                
                if (!validationError.isEmpty()) {
                    qDebug() << "updateSignalParameter: Validation failed for signal" << signalName << ":" << validationError;
                    return false;
                }
                
                // If validation passes, update the parameter
                if (paramName == "startBit") {
                    sig.startBit = newStartBit;
                } else if (paramName == "length") {
                    sig.length = newLength;
                }
            }
            
            // Notify QML that the signal model has changed
            emit signalModelChanged();
            emit generatedCanFrameChanged();
            
            return true;
        }
    }
    
    return false;
}

// NEW FUNCTION: Check if a bit belongs to a signal (exposed to QML)
bool DbcParser::isBitPartOfSignal(const QString &signalName, int byteIndex, int bitIndex)
{
    if (selectedMessageIndex < 0 || selectedMessageIndex >= static_cast<int>(messages.size())) {
        return false;
    }
    
    auto& msg = messages[selectedMessageIndex];
    
    for (auto& sig : msg.signalList) {
        if (QString::fromStdString(sig.name) == signalName) {
            // Calculate the bit position
            int bitPosition = byteIndex * 8 + bitIndex;
            
            // Use the private helper method to check if the bit is part of the signal
            return isBitPartOfSignal(bitPosition, sig.startBit, sig.length, sig.littleEndian);
        }
    }
    
    return false;
}

// Improved helper function for bit endianness
bool DbcParser::isBitPartOfSignal(int bitPosition, int startBit, int length, bool littleEndian)
{
    if (littleEndian) {
        // For little endian (Intel format), bits are consecutive from startBit
        int endBit = startBit + length - 1;
        return (bitPosition >= startBit && bitPosition <= endBit);
    } else {
        // For big endian (Motorola format), bits start at startBit and go backwards
        // Convert to standard Motorola bit numbering
        int byteIndex = startBit / 8;
        int bitIndexInByte = startBit % 8;
        
        // MSB (Most Significant Bit) is the startBit
        int msb = byteIndex * 8 + (7 - bitIndexInByte);
        // LSB (Least Significant Bit) is length-1 bits from MSB
        int lsb = msb - (length - 1);
        
        return (bitPosition <= msb && bitPosition >= lsb);
    }
}

// Get frame data as hex string
// Get frame data as hex string
QString DbcParser::getFrameDataHex(const QString &signalName, double rawValue)
{
    if (selectedMessageIndex < 0 || selectedMessageIndex >= static_cast<int>(messages.size())) {
        return "00 00 00 00 00 00 00 00";
    }
    
    auto msg = messages[selectedMessageIndex]; // Make a non-const copy
    
    // Create a buffer of zeros for the CAN frame data
    std::vector<uint8_t> frameData(msg.length, 0);
    
    // Store original signal value
    double originalValue = 0.0;
    int signalIndex = -1;
    
    // Find the signal
    for (size_t i = 0; i < msg.signalList.size(); i++) {
        if (QString::fromStdString(msg.signalList[i].name) == signalName) {
            originalValue = msg.signalList[i].value;
            signalIndex = static_cast<int>(i);
            break;
        }
    }
    
    if (signalIndex < 0) {
        return "00 00 00 00 00 00 00 00";
    }
    
    // Set the signal value based on raw value
    msg.signalList[signalIndex].value = calculatePhysicalValue(signalName, rawValue);
    
    // For each signal, pack its value into the frame based on the SAME logic as buildCanFrame()
    for (const auto& sig : msg.signalList) {
        // Convert the physical value to raw value
        double sigRawValue = (sig.value - sig.offset) / sig.factor;
        
        // Clamp to min/max if defined
        if (sig.min != sig.max) {
            sigRawValue = std::max(sig.min, std::min(sigRawValue, sig.max));
        }
        
        // Round to integer
        uint64_t intValue = static_cast<uint64_t>(std::round(sigRawValue));
        
        // Apply bit mask based on signal length
        uint64_t mask = (1ULL << sig.length) - 1;
        intValue &= mask;
        
        // Pack the value into the frame based on endianness
        int startBit = sig.startBit;
        
        if (sig.littleEndian) {
            // Little endian (Intel format)
            for (int i = 0; i < sig.length; i++) {
                int byteIndex = startBit / 8;
                int bitIndex = startBit % 8;
                
                if (byteIndex < msg.length) {
                    // Set or clear bit
                    if (intValue & (1ULL << i)) {
                        frameData[byteIndex] |= (1 << bitIndex);
                    } else {
                        frameData[byteIndex] &= ~(1 << bitIndex);
                    }
                }
                
                startBit++;
            }
        } else {
            // Big endian (Motorola format)
            int msb = startBit;
            for (int i = 0; i < sig.length; i++) {
                int byteIndex = msb / 8;
                int bitIndex = 7 - (msb % 8);
                
                if (byteIndex < msg.length) {
                    // Set or clear bit
                    if (intValue & (1ULL << (sig.length - 1 - i))) {
                        frameData[byteIndex] |= (1 << bitIndex);
                    } else {
                        frameData[byteIndex] &= ~(1 << bitIndex);
                    }
                }
                
                // Decrement for Motorola format
                msb--;
                if (msb < 0) break;
            }
        }
    }
    
    // Format the frame data as a hex string
    std::stringstream ss;
    ss << "Data: ";
    for (size_t i = 0; i < frameData.size(); i++) {
        ss << std::hex << std::uppercase << std::setw(2) << std::setfill('0') << static_cast<int>(frameData[i]);
        if (i < frameData.size() - 1) {
            ss << " ";
        }
    }
    
    return QString::fromStdString(ss.str());
}
// Get frame data as binary string
QString DbcParser::getFrameDataBin(const QString &signalName, double rawValue)
{
    if (selectedMessageIndex < 0 || selectedMessageIndex >= static_cast<int>(messages.size())) {
        return "00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000";
    }
    
    auto msg = messages[selectedMessageIndex]; // Make a non-const copy
    
    // Create a buffer of zeros for the CAN frame data
    std::vector<uint8_t> frameData(msg.length, 0);
    
    // Find the signal
    int signalIndex = -1;
    for (size_t i = 0; i < msg.signalList.size(); i++) {
        if (QString::fromStdString(msg.signalList[i].name) == signalName) {
            signalIndex = static_cast<int>(i);
            break;
        }
    }
    
    if (signalIndex < 0) {
        return "00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000";
    }
    
    // Set the signal value based on raw value
    msg.signalList[signalIndex].value = calculatePhysicalValue(signalName, rawValue);
    
    // For each signal, pack its value into the frame based on the SAME logic as buildCanFrame()
    for (const auto& s : msg.signalList) {
        // Convert the physical value to raw value
        double sigRawValue = (s.value - s.offset) / s.factor;
        
        // Clamp to min/max if defined
        if (s.min != s.max) {
            sigRawValue = std::max(s.min, std::min(sigRawValue, s.max));
        }
        
        // Round to integer
        uint64_t intValue = static_cast<uint64_t>(std::round(sigRawValue));
        
        // Apply bit mask based on signal length
        uint64_t mask = (1ULL << s.length) - 1;
        intValue &= mask;
        
        // Pack the value into the frame based on endianness
        int startBit = s.startBit;
        
        if (s.littleEndian) {
            // Little endian (Intel format)
            for (int i = 0; i < s.length; i++) {
                int byteIndex = startBit / 8;
                int bitIndex = startBit % 8;
                
                if (byteIndex < msg.length) {
                    // Set or clear bit
                    if (intValue & (1ULL << i)) {
                        frameData[byteIndex] |= (1 << bitIndex);
                    } else {
                        frameData[byteIndex] &= ~(1 << bitIndex);
                    }
                }
                
                startBit++;
            }
        } else {
            // Big endian (Motorola format)
            int msb = startBit;
            for (int i = 0; i < s.length; i++) {
                int byteIndex = msb / 8;
                int bitIndex = 7 - (msb % 8);
                
                if (byteIndex < msg.length) {
                    // Set or clear bit
                    if (intValue & (1ULL << (s.length - 1 - i))) {
                        frameData[byteIndex] |= (1 << bitIndex);
                    } else {
                        frameData[byteIndex] &= ~(1 << bitIndex);
                    }
                }
                
                // Decrement for Motorola format
                msb--;
                if (msb < 0) break;
            }
        }
    }
    
    // Format the frame data as a binary string
   std::stringstream ss;
    for (size_t i = 0; i < frameData.size(); i++) {
        for (int bit = 7; bit >= 0; bit--) {
            ss << ((frameData[i] & (1 << bit)) ? "1" : "0");
        }
        if (i < frameData.size() - 1) {
            ss << " ";
        }
    }
    
    return QString::fromStdString(ss.str());
}
int DbcParser::getBitIndexInRawValue(int bitPosition, int startBit, bool littleEndian)
{
    if (littleEndian) {
        // For little endian (Intel format), the bit index is the offset from the start bit
        return bitPosition - startBit;
    } else {
        // For big endian (Motorola format), convert to standard bit numbering
        int startByteIndex = startBit / 8;
        int startBitIndex = startBit % 8;
        
        // MSB (Most Significant Bit) is the startBit in Motorola format
        int msb = startByteIndex * 8 + (7 - startBitIndex);
        
        // Calculate bit index from MSB (counting down)
        return msb - bitPosition;
    }
}
QString DbcParser::getModifiedDbcText() const {
    // If no messages loaded, return the original text unchanged
    if (messages.empty()) {
        return originalDbcText.trimmed();
    }
    
    // Start with the original text and only modify specific messages that have changed
    QStringList lines = originalDbcText.split('\n');
    QStringList result;
    
    // Parse original file to create a map of message ID -> original lines
    QMap<unsigned long, QStringList> originalMessages;
    QMap<unsigned long, int> originalMessageLineNumbers;
    
    // Parse the current in-memory messages to create a map of message ID -> current state
    QMap<unsigned long, QStringList> currentMessages;
    for (const auto& msg : messages) {
        QStringList msgLines;
        msgLines << QString("BO_ %1 %2: %3 Vector__XXX")
                       .arg(msg.id)
                       .arg(QString::fromStdString(msg.name))
                       .arg(msg.length);

        for (const auto& sig : msg.signalList) {
            QString endian = sig.littleEndian ? "1" : "0";
            msgLines << QString("   SG_ %1 : %2|%3@%4+ (%5,%6) [%7|%8] \"%9\" Vector__XXX")
                           .arg(QString::fromStdString(sig.name))
                           .arg(sig.startBit)
                           .arg(sig.length)
                           .arg(endian)
                           .arg(sig.factor)
                           .arg(sig.offset)
                           .arg(sig.min)
                           .arg(sig.max)
                           .arg(QString::fromStdString(sig.unit));
        }
        
        // Add an empty line after each message to match original formatting
        msgLines << "";
        
        currentMessages[msg.id] = msgLines;
    }
    
    // Now parse the original file to extract the original message structures
    int i = 0;
    while (i < lines.size()) {
        QString line = lines[i].trimmed();
        
        // Check if this line starts a message
        if (line.startsWith("BO_")) {
            // Extract message ID from the BO_ line
            QStringList parts = line.split(" ", Qt::SkipEmptyParts);
            if (parts.size() >= 2) {
                bool ok;
                unsigned long msgId = parts[1].toULong(&ok);
                if (ok) {
                    // Collect all lines for this message (BO_ line + all SG_ lines)
                    QStringList originalMsgLines;
                    originalMsgLines << lines[i]; // The BO_ line
                    originalMessageLineNumbers[msgId] = i;
                    
                    int j = i + 1;
                    // Collect all signal lines that belong to this message
                    while (j < lines.size()) {
                        QString sigLine = lines[j].trimmed();
                        if (sigLine.startsWith("SG_") || sigLine.contains(" SG_")) {
                            originalMsgLines << lines[j];
                            j++;
                        } else if (sigLine.isEmpty()) {
                            // Keep empty lines within the message - they are part of the original formatting
                            originalMsgLines << lines[j];
                            j++;
                        } else {
                            // Hit a non-signal, non-empty line - message definition is done
                            break;
                        }
                    }
                    
                    originalMessages[msgId] = originalMsgLines;
                    i = j - 1; // -1 because the loop will increment i
                }
            }
        }
        i++;
    }
    
    // Now rebuild the file, line by line
    i = 0;
    while (i < lines.size()) {
        QString line = lines[i].trimmed();
        
        // Check if this line starts a message
        if (line.startsWith("BO_")) {
            // Extract message ID
            QStringList parts = line.split(" ", Qt::SkipEmptyParts);
            if (parts.size() >= 2) {
                bool ok;
                unsigned long msgId = parts[1].toULong(&ok);
                if (ok && currentMessages.contains(msgId)) {
                    // Check if this message has actually changed
                    QStringList originalMsgLines = originalMessages.value(msgId);
                    QStringList currentMsgLines = currentMessages.value(msgId);
                    
                    if (originalMsgLines == currentMsgLines) {
                        // Message unchanged - copy original lines exactly
                        for (const QString& origLine : originalMsgLines) {
                            result << origLine;
                        }
                    } else {
                        // Message changed - use current version
                        for (const QString& currentLine : currentMsgLines) {
                            result << currentLine;
                        }
                    }
                    
                    // Skip over the rest of this message in the original file
                    i++; // Move past the BO_ line
                    while (i < lines.size()) {
                        QString nextLine = lines[i].trimmed();
                        if (nextLine.startsWith("SG_") || nextLine.contains(" SG_") || nextLine.isEmpty()) {
                            i++; // Skip signal lines and empty lines
                        } else {
                            i--; // Back up one so the outer loop will process this line
                            break;
                        }
                    }
                } else {
                    // Message not found in current messages - copy original line
                    result << lines[i];
                }
            } else {
                // Malformed BO_ line - copy as-is
                result << lines[i];
            }
        } else {
            // Non-message line - copy as-is (headers, attributes, comments, etc.)
            result << lines[i];
        }
        
        i++;
    }
    
    // After processing all original lines, add any new messages that weren't in the original file
    for (auto it = currentMessages.begin(); it != currentMessages.end(); ++it) {
        unsigned long msgId = it.key();
        if (!originalMessages.contains(msgId)) {
            // This is a new message - add it to the result
            QStringList newMsgLines = it.value();
            for (const QString& newLine : newMsgLines) {
                result << newLine;
            }
        }
    }
    
    return result.join('\n').trimmed();
}
QString DbcParser::getOriginalDbcText() const {
    return originalDbcText.trimmed();
}
bool DbcParser::saveModifiedDbcToFile(const QUrl &saveUrl) {
    QString path = saveUrl.toLocalFile();
    if (path.isEmpty()) return false;

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "Could not write to file:" << path;
        return false;
    }

    QTextStream out(&file);
    out << getModifiedDbcText();
    file.close();
    return true;
}
QStringList DbcParser::getDbcDiffLines() {
    QStringList originalLines = originalDbcText.split('\n');
    QStringList modifiedLines = getModifiedDbcText().split('\n');

    QStringList diff;

    int o = 0, m = 0;
    while (o < originalLines.size() && m < modifiedLines.size()) {
        if (originalLines[o] == modifiedLines[m]) {
            diff << "  " + originalLines[o]; // unchanged
            o++; m++;
        } else if (!modifiedLines.contains(originalLines[o])) {
            diff << "- " + originalLines[o]; // removed
            o++;
        } else if (!originalLines.contains(modifiedLines[m])) {
            diff << "+ " + modifiedLines[m]; // added
            m++;
        } else {
            diff << "- " + originalLines[o];
            diff << "+ " + modifiedLines[m];
            o++; m++;
        }
    }

    // Remaining additions
    while (m < modifiedLines.size()) {
        diff << "+ " + modifiedLines[m++];
    }

    // Remaining deletions
    while (o < originalLines.size()) {
        diff << "- " + originalLines[o++];
    }

    return diff;
}

QVariantMap DbcParser::getStructuredDiff() {
    QString originalText = originalDbcText;
    QString modifiedText = getModifiedDbcText();
    
    QVariantList originalContent;
    QVariantList modifiedContent;
    
    // Quick check: if the texts are identical, show the entire file with no changes marked
    if (originalText == modifiedText) {
        // Show all lines of the original file
        QStringList originalLines = originalText.split('\n');
        for (int i = 0; i < originalLines.size(); i++) {
            QVariantMap lineData;
            lineData["text"] = originalLines[i];
            lineData["changed"] = false;
            lineData["lineNumber"] = i + 1;
            originalContent.append(lineData);
        }
        
        // For the modified side, show a message indicating no changes were made
        QVariantMap noChangesData;
        noChangesData["text"] = "No changes made to the DBC file";
        noChangesData["changed"] = false;
        noChangesData["lineNumber"] = 1;
        modifiedContent.append(noChangesData);
        
        QVariantMap result;
        result["original"] = originalContent;
        result["modified"] = modifiedContent;
        return result;
    }
    
    QStringList originalLines = originalText.split('\n');
    QStringList modifiedLines = modifiedText.split('\n');
    
    // Find lines that are actually different
    QSet<int> changedOriginalLines;
    QSet<int> changedModifiedLines;
    
    // Check if files have different line counts or content
    bool hasRealChanges = false;
    
    // Compare line by line exactly
    int maxLines = qMax(originalLines.size(), modifiedLines.size());
    for (int i = 0; i < maxLines; i++) {
        QString origLine = (i < originalLines.size()) ? originalLines[i] : "";
        QString modLine = (i < modifiedLines.size()) ? modifiedLines[i] : "";
        
        if (origLine != modLine) {
            hasRealChanges = true;
            if (i < originalLines.size()) changedOriginalLines.insert(i);
            if (i < modifiedLines.size()) changedModifiedLines.insert(i);
            
            // Add context around changed lines (1 line before and after)
            for (int j = qMax(0, i-1); j <= qMin(originalLines.size()-1, i+1); j++) {
                changedOriginalLines.insert(j);
            }
            for (int j = qMax(0, i-1); j <= qMin(modifiedLines.size()-1, i+1); j++) {
                changedModifiedLines.insert(j);
            }
        }
    }
    
    // If no real changes detected, show the entire original file and indicate no changes
    if (!hasRealChanges) {
        for (int i = 0; i < originalLines.size(); i++) {
            QVariantMap lineData;
            lineData["text"] = originalLines[i];
            lineData["changed"] = false;
            lineData["lineNumber"] = i + 1;
            originalContent.append(lineData);
        }
        
        // For the modified side, show a message indicating no changes were made
        QVariantMap noChangesData;
        noChangesData["text"] = "No changes made to the DBC file";
        noChangesData["changed"] = false;
        noChangesData["lineNumber"] = 1;
        modifiedContent.append(noChangesData);
    } else {
        // Show only changed sections and their context
        QList<int> originalLinesToShow = changedOriginalLines.values();
        std::sort(originalLinesToShow.begin(), originalLinesToShow.end());
        
        for (int lineNum : originalLinesToShow) {
            if (lineNum < originalLines.size()) {
                QVariantMap lineData;
                lineData["text"] = originalLines[lineNum];
                lineData["changed"] = (originalLines[lineNum] != 
                    (lineNum < modifiedLines.size() ? modifiedLines[lineNum] : ""));
                lineData["lineNumber"] = lineNum + 1;
                originalContent.append(lineData);
            }
        }
        
        QList<int> modifiedLinesToShow = changedModifiedLines.values();
        std::sort(modifiedLinesToShow.begin(), modifiedLinesToShow.end());
        
        for (int lineNum : modifiedLinesToShow) {
            if (lineNum < modifiedLines.size()) {
                QVariantMap lineData;
                lineData["text"] = modifiedLines[lineNum];
                lineData["changed"] = (modifiedLines[lineNum] != 
                    (lineNum < originalLines.size() ? originalLines[lineNum] : ""));
                lineData["lineNumber"] = lineNum + 1;
                modifiedContent.append(lineData);
            }
        }
    }
    
    QVariantMap result;
    result["original"] = originalContent;
    result["modified"] = modifiedContent;
    return result;
}

// Add these implementations to DbcParser.cpp

bool DbcParser::addMessage(const QString &name, unsigned long id, int length)
{
    // Check if message with same name or ID already exists
    for (const auto& msg : messages) {
        if (QString::fromStdString(msg.name) == name || msg.id == id) {
            qWarning() << "Message with name" << name << "or ID" << id << "already exists";
            return false;
        }
    }

    // Create new message
    canMessage newMessage;
    newMessage.name = name.toStdString();
    newMessage.id = id;
    newMessage.length = length;
    newMessage.signalList.clear();

    // Add to messages vector
    messages.push_back(newMessage);

    // Notify QML
    emit messageModelChanged();

    return true;
}

bool DbcParser::removeMessage(const QString &messageName)
{
    for (auto it = messages.begin(); it != messages.end(); ++it) {
        if (QString::fromStdString(it->name) == messageName) {
            // If this message is currently selected, reset selection
            if (selectedMessageIndex == std::distance(messages.begin(), it)) {
                selectedMessageIndex = -1;
                emit signalModelChanged();
            }

            messages.erase(it);
            emit messageModelChanged();
            emit generatedCanFrameChanged();
            return true;
        }
    }

    return false;
}

bool DbcParser::addSignal(const QString &messageName, const QString &signalName,
                          int startBit, int length, bool littleEndian,
                          double factor, double offset, double min, double max,
                          const QString &unit)
{
    // Find the message
    for (auto& msg : messages) {
        if (QString::fromStdString(msg.name) == messageName) {
            // Check if signal with same name already exists in this message
            for (const auto& sig : msg.signalList) {
                if (QString::fromStdString(sig.name) == signalName) {
                    qWarning() << "Signal" << signalName << "already exists in message" << messageName;
                    return false;
                }
            }

            // Check if bits would overlap with existing signals
            for (const auto& sig : msg.signalList) {
                bool overlap = false;
                
                if (littleEndian && sig.littleEndian) {
                    // Both little endian
                    int newEndBit = startBit + length - 1;
                    int existingEndBit = sig.startBit + sig.length - 1;
                    overlap = !(newEndBit < sig.startBit || startBit > existingEndBit);
                }
                else if (!littleEndian && !sig.littleEndian) {
                    // Both big endian (Motorola format)
                    // For Motorola, startBit is MSB, need to calculate bit ranges
                    int newMsb = startBit;
                    int newLsb = getMotorolaLsb(startBit, length);
                    int existingMsb = sig.startBit;
                    int existingLsb = getMotorolaLsb(sig.startBit, sig.length);
                    
                    overlap = !(newLsb > existingMsb || newMsb < existingLsb);
                }
                else {
                    // Mixed endianness - convert to absolute bit positions for comparison
                    std::set<int> newBits = getSignalBitPositions(startBit, length, littleEndian);
                    std::set<int> existingBits = getSignalBitPositions(sig.startBit, sig.length, sig.littleEndian);
                    
                    // Check for intersection
                    for (int bit : newBits) {
                        if (existingBits.count(bit) > 0) {
                            overlap = true;
                            break;
                        }
                    }
                }
                
                if (overlap) {
                    qWarning() << "Signal bits would overlap with existing signal" << QString::fromStdString(sig.name);
                    return false;
                }
            }

            // Create new signal
            canSignal newSignal;
            newSignal.name = signalName.toStdString();
            newSignal.startBit = startBit;
            newSignal.length = length;
            newSignal.littleEndian = littleEndian;
            newSignal.factor = factor;
            newSignal.offset = offset;
            newSignal.min = min;
            newSignal.max = max;
            newSignal.unit = unit.toStdString();
            newSignal.value = 0.0; // Initialize with default value

            // Add to signal list
            msg.signalList.push_back(newSignal);

            // Always emit signal model changed if we're adding to any message
            // This ensures the UI updates properly
            emit signalModelChanged();
            emit generatedCanFrameChanged();

            return true;
        }
    }

    qWarning() << "Message" << messageName << "not found";
    return false;
}

bool DbcParser::removeSignal(const QString &messageName, const QString &signalName)
{
    for (auto& msg : messages) {
        if (QString::fromStdString(msg.name) == messageName) {
            for (auto it = msg.signalList.begin(); it != msg.signalList.end(); ++it) {
                if (QString::fromStdString(it->name) == signalName) {
                    msg.signalList.erase(it);

                    // If this message is currently selected, update the signal model
                    if (selectedMessageIndex >= 0 &&
                        selectedMessageIndex < static_cast<int>(messages.size()) &&
                        QString::fromStdString(messages[selectedMessageIndex].name) == messageName) {
                        emit signalModelChanged();
                        emit generatedCanFrameChanged();
                    }

                    return true;
                }
            }
        }
    }

    return false;
}

bool DbcParser::messageExists(const QString &messageName)
{
    // Extract the clean message name (remove ID part if present)
    int parenthesisPos = messageName.indexOf(" (");
    QString cleanMessageName = parenthesisPos > 0 ? messageName.left(parenthesisPos) : messageName;
    
    for (const auto& msg : messages) {
        if (QString::fromStdString(msg.name) == cleanMessageName) {
            return true;
        }
    }
    return false;
}

bool DbcParser::signalExists(const QString &messageName, const QString &signalName)
{
    for (const auto& msg : messages) {
        if (QString::fromStdString(msg.name) == messageName) {
            for (const auto& sig : msg.signalList) {
                if (QString::fromStdString(sig.name) == signalName) {
                    return true;
                }
            }
        }
    }
    return false;
}
bool DbcParser::isValidMessageId(unsigned long id)
{
    // Check if ID is within valid CAN ID range
    // Standard CAN: 0x000 to 0x7FF (11-bit)
    // Extended CAN: 0x00000000 to 0x1FFFFFFF (29-bit)
    if (id > 0x1FFFFFFF) {
        return false;
    }

    // Check if ID is already in use
    for (const auto& msg : messages) {
        if (msg.id == id) {
            return false;
        }
    }

    return true;
}

bool DbcParser::isValidSignalPosition(const QString &messageName, int startBit, int length, bool littleEndian)
{
    // Find the message
    for (const auto& msg : messages) {
        if (QString::fromStdString(msg.name) == messageName) {
            // Check if signal fits within message length
            if (littleEndian) {
                if ((startBit + length) > (msg.length * 8)) {
                    return false;
                }
            } else {
                // For big endian, need different calculation
                int byteIndex = startBit / 8;
                if (byteIndex >= msg.length) {
                    return false;
                }
            }

            return true;
        }
    }

    return false;
}

// Enhanced validation methods with detailed error messages
QString DbcParser::validateMessageData(const QString &name, unsigned long id, int length)
{
    // Check name
    if (name.trimmed().isEmpty()) {
        return "Message name cannot be empty";
    }
    
    // Check if name already exists
    for (const auto& msg : messages) {
        if (QString::fromStdString(msg.name) == name) {
            return "Message name '" + name + "' already exists";
        }
    }
    
    // Check ID range
    if (id > 0x1FFFFFFF) {
        return "Message ID 0x" + QString::number(id, 16).toUpper() + " exceeds maximum CAN ID (0x1FFFFFFF)";
    }
    
    // Check if ID already exists
    for (const auto& msg : messages) {
        if (msg.id == id) {
            return "Message ID 0x" + QString::number(id, 16).toUpper() + " already exists in message '" + QString::fromStdString(msg.name) + "'";
        }
    }
    
    // Check length
    if (length < 1 || length > 8) {
        return "Message length must be between 1 and 8 bytes";
    }
    
    return ""; // No errors
}

QString DbcParser::validateSignalData(const QString &messageName, const QString &signalName,
                                      int startBit, int length, bool littleEndian)
{
    return validateSignalData(messageName, signalName, startBit, length, littleEndian, QString());
}

QString DbcParser::validateSignalData(const QString &messageName, const QString &signalName,
                                      int startBit, int length, bool littleEndian, const QString &excludeSignal)
{
    // Check signal name
    if (signalName.trimmed().isEmpty()) {
        return "Signal name cannot be empty";
    }
    
    // Find the message
    const canMessage* targetMessage = nullptr;
    for (const auto& msg : messages) {
        if (QString::fromStdString(msg.name) == messageName) {
            targetMessage = &msg;
            break;
        }
    }
    
    if (!targetMessage) {
        return "Message '" + messageName + "' not found";
    }
    
    // Check if signal name already exists in this message (exclude the signal being edited)
    if (excludeSignal.isEmpty() || signalName != excludeSignal) {
        for (const auto& sig : targetMessage->signalList) {
            if (QString::fromStdString(sig.name) == signalName) {
                return "Signal name '" + signalName + "' already exists in message '" + messageName + "'";
            }
        }
    }
    
    // Check length
    if (length < 1 || length > 64) {
        return "Signal length must be between 1 and 64 bits";
    }
    
    // Check if signal fits within message
    if (littleEndian) {
        if ((startBit + length) > (targetMessage->length * 8)) {
            return "Signal extends beyond message boundary (bit " + QString::number(startBit + length - 1) + " > " + QString::number(targetMessage->length * 8 - 1) + ")";
        }
    } else {
        // For Motorola format, startBit is MSB
        int byteIndex = startBit / 8;
        if (byteIndex >= targetMessage->length) {
            return "Signal start bit is beyond message boundary";
        }
        
        // Check if signal extends below bit 0
        int lsb = getMotorolaLsb(startBit, length);
        if (lsb < 0) {
            return "Signal extends below bit 0 in Motorola format";
        }
    }
    
    // Check for overlaps with existing signals (exclude the signal being edited)
    for (const auto& sig : targetMessage->signalList) {
        QString conflictingSignal = QString::fromStdString(sig.name);
        
        // Skip the signal being edited
        if (!excludeSignal.isEmpty() && conflictingSignal == excludeSignal) {
            continue;
        }
        
        bool overlap = false;
        
        if (littleEndian && sig.littleEndian) {
            // Both little endian
            int newEndBit = startBit + length - 1;
            int existingEndBit = sig.startBit + sig.length - 1;
            overlap = !(newEndBit < sig.startBit || startBit > existingEndBit);
        }
        else if (!littleEndian && !sig.littleEndian) {
            // Both big endian
            int newMsb = startBit;
            int newLsb = getMotorolaLsb(startBit, length);
            int existingMsb = sig.startBit;
            int existingLsb = getMotorolaLsb(sig.startBit, sig.length);
            
            overlap = !(newLsb > existingMsb || newMsb < existingLsb);
        }
        else {
            // Mixed endianness - use bit position sets
            std::set<int> newBits = getSignalBitPositions(startBit, length, littleEndian);
            std::set<int> existingBits = getSignalBitPositions(sig.startBit, sig.length, sig.littleEndian);
            
            // Check for intersection
            for (int bit : newBits) {
                if (existingBits.count(bit) > 0) {
                    overlap = true;
                    break;
                }
            }
        }
        
        if (overlap) {
            return "Signal bits overlap with existing signal '" + conflictingSignal + "' (start bit " + QString::number(sig.startBit) + ", length " + QString::number(sig.length) + ")";
        }
    }
    
    return ""; // No errors
}

bool DbcParser::checkSignalOverlap(const QString &messageName, int startBit, int length, bool littleEndian)
{
    for (const auto& msg : messages) {
        if (QString::fromStdString(msg.name) == messageName) {
            for (const auto& sig : msg.signalList) {
                bool overlap = false;
                
                if (littleEndian && sig.littleEndian) {
                    // Both little endian
                    int newEndBit = startBit + length - 1;
                    int existingEndBit = sig.startBit + sig.length - 1;
                    overlap = !(newEndBit < sig.startBit || startBit > existingEndBit);
                }
                else if (!littleEndian && !sig.littleEndian) {
                    // Both big endian
                    int newMsb = startBit;
                    int newLsb = getMotorolaLsb(startBit, length);
                    int existingMsb = sig.startBit;
                    int existingLsb = getMotorolaLsb(sig.startBit, sig.length);
                    
                    overlap = !(newLsb > existingMsb || newMsb < existingLsb);
                }
                else {
                    // Mixed endianness
                    std::set<int> newBits = getSignalBitPositions(startBit, length, littleEndian);
                    std::set<int> existingBits = getSignalBitPositions(sig.startBit, sig.length, sig.littleEndian);
                    
                    for (int bit : newBits) {
                        if (existingBits.count(bit) > 0) {
                            overlap = true;
                            break;
                        }
                    }
                }
                
                if (overlap) {
                    return true;
                }
            }
            break;
        }
    }
    return false;
}

int DbcParser::getNextAvailableStartBit(const QString &messageName, int length)
{
    // Find the message
    const canMessage* targetMessage = nullptr;
    for (const auto& msg : messages) {
        if (QString::fromStdString(msg.name) == messageName) {
            targetMessage = &msg;
            break;
        }
    }
    
    if (!targetMessage) {
        qWarning() << "Message not found:" << messageName;
        return 0; // Default to start bit 0 if message not found
    }
    
    int maxBits = targetMessage->length * 8; // Total bits in message
    
    // Try each possible start bit position
    for (int startBit = 0; startBit <= maxBits - length; startBit++) {
        bool hasOverlap = false;
        
        // Check against all existing signals
        for (const auto& sig : targetMessage->signalList) {
            bool overlap = false;
            
            // Assume little endian for simplicity in auto-assignment
            int newEndBit = startBit + length - 1;
            int existingEndBit = sig.startBit + sig.length - 1;
            
            if (sig.littleEndian) {
                // Both little endian
                overlap = !(newEndBit < sig.startBit || startBit > existingEndBit);
            } else {
                // Mixed endianness - use bit position sets for accuracy
                std::set<int> newBits = getSignalBitPositions(startBit, length, true); // Assume little endian for new signal
                std::set<int> existingBits = getSignalBitPositions(sig.startBit, sig.length, sig.littleEndian);
                
                // Check for intersection
                for (int bit : newBits) {
                    if (existingBits.count(bit) > 0) {
                        overlap = true;
                        break;
                    }
                }
            }
            
            if (overlap) {
                hasOverlap = true;
                break;
            }
        }
        
        if (!hasOverlap) {
            return startBit; // Found an available position
        }
    }
    
    // No available position found
    qWarning() << "No available start bit position found for message" << messageName << "with length" << length;
    return -1;
}

bool DbcParser::isBitOccupied(const QString &messageName, int bitIndex)
{
    // Find the message
    const canMessage* targetMessage = nullptr;
    for (const auto& msg : messages) {
        if (QString::fromStdString(msg.name) == messageName) {
            targetMessage = &msg;
            break;
        }
    }
    
    if (!targetMessage) {
        return false;
    }
    
    // Check if this bit is occupied by any existing signal
    for (const auto& sig : targetMessage->signalList) {
        std::set<int> signalBits = getSignalBitPositions(sig.startBit, sig.length, sig.littleEndian);
        
        if (signalBits.count(bitIndex) > 0) {
            return true;
        }
    }
    
    return false;
}

QString DbcParser::getBitOccupiedBy(const QString &messageName, int bitIndex)
{
    // Find the message
    const canMessage* targetMessage = nullptr;
    for (const auto& msg : messages) {
        if (QString::fromStdString(msg.name) == messageName) {
            targetMessage = &msg;
            break;
        }
    }
    
    if (!targetMessage) {
        return "";
    }
    
    // Find which signal occupies this bit
    for (const auto& sig : targetMessage->signalList) {
        std::set<int> signalBits = getSignalBitPositions(sig.startBit, sig.length, sig.littleEndian);
        
        if (signalBits.count(bitIndex) > 0) {
            return QString::fromStdString(sig.name);
        }
    }
    
    return "";
}

// Helper function to calculate LSB for Motorola format
int DbcParser::getMotorolaLsb(int msb, int length)
{
    int msbByte = msb / 8;
    int msbBitInByte = msb % 8;
    
    // Calculate absolute MSB position
    int absoluteMsb = msbByte * 8 + (7 - msbBitInByte);
    
    // LSB is length-1 bits away
    int absoluteLsb = absoluteMsb - (length - 1);
    
    return absoluteLsb;
}

// Helper function to get all bit positions occupied by a signal
std::set<int> DbcParser::getSignalBitPositions(int startBit, int length, bool littleEndian)
{
    std::set<int> bitPositions;
    
    if (littleEndian) {
        // Intel format: consecutive bits from startBit
        for (int i = 0; i < length; i++) {
            bitPositions.insert(startBit + i);
        }
    } else {
        // Motorola format: startBit is MSB
        int msb = startBit;
        for (int i = 0; i < length; i++) {
            int byteIndex = msb / 8;
            int bitIndex = msb % 8;
            int absolutePosition = byteIndex * 8 + (7 - bitIndex);
            bitPositions.insert(absolutePosition);
            msb--;
            if (msb < 0) break;
        }
    }
    
    return bitPositions;
}
// Add these method implementations to your DbcParser.cpp file:

QString DbcParser::prepareCanMessage(const QString &messageName, int rateMs)
{
    qDebug() << "DbcParser::prepareCanMessage called with messageName:" << messageName << "rateMs:" << rateMs;
    
    // Extract the message name without the ID part
    int parenthesisPos = messageName.indexOf(" (");
    QString name = parenthesisPos > 0 ? messageName.left(parenthesisPos) : messageName;
    
    qDebug() << "Extracted message name:" << name;

    for (const auto& msg : messages) {
        if (QString::fromStdString(msg.name) == name) {
            // Get the message ID
            unsigned long canId = msg.id;

            // Generate the hex data for this message
            QString hexData = getMessageHexData(messageName);

            // New format: "canid#canmessage#rate#canbus"
            // Remove spaces from hexData and format as continuous hex string
            QString cleanHexData = hexData;
            cleanHexData.remove(" ");
            
            QString result = QString("%1#%2#%3#vcan0").arg(canId, 0, 16, QChar('0')).arg(cleanHexData).arg(rateMs);
            qDebug() << "Prepared message:" << result;
            qDebug() << "  - CAN ID:" << QString::number(canId, 16);
            qDebug() << "  - Hex Data:" << cleanHexData;
            qDebug() << "  - Rate:" << rateMs;
            
            return result;
        }
    }

    qDebug() << "Message not found:" << name;
    return QString();
}

QString DbcParser::prepareCanMessage(const QString &messageName, int rateMs, const QString &canBus)
{
    qDebug() << "DbcParser::prepareCanMessage called with messageName:" << messageName << "rateMs:" << rateMs << "canBus:" << canBus;
    
    // Extract the message name without the ID part
    int parenthesisPos = messageName.indexOf(" (");
    QString name = parenthesisPos > 0 ? messageName.left(parenthesisPos) : messageName;
    
    qDebug() << "Extracted message name:" << name;

    for (const auto& msg : messages) {
        if (QString::fromStdString(msg.name) == name) {
            // Get the message ID
            unsigned long canId = msg.id;

            // Generate the hex data for this message
            QString hexData = getMessageHexData(messageName);

            // New format: "canid#canmessage#rate#canbus"
            // Remove spaces from hexData and format as continuous hex string
            QString cleanHexData = hexData;
            cleanHexData.remove(" ");
            
            // Use the provided CAN bus instead of hardcoded "vcan0"
            QString busToUse = canBus.isEmpty() ? "vcan0" : canBus;
            QString result = QString("%1#%2#%3#%4").arg(canId, 0, 16, QChar('0')).arg(cleanHexData).arg(rateMs).arg(busToUse);
            qDebug() << "Prepared message:" << result;
            qDebug() << "  - CAN ID:" << QString::number(canId, 16);
            qDebug() << "  - Hex Data:" << cleanHexData;
            qDebug() << "  - Rate:" << rateMs;
            qDebug() << "  - CAN Bus:" << busToUse;
            
            return result;
        }
    }

    qDebug() << "Message not found:" << name;
    return QString();
}

QString DbcParser::getMessageHexData(const QString &messageName)
{
    // Extract the message name without the ID part
    int parenthesisPos = messageName.indexOf(" (");
    QString name = parenthesisPos > 0 ? messageName.left(parenthesisPos) : messageName;

    // Find the message index
    int messageIndex = -1;
    for (int i = 0; i < static_cast<int>(messages.size()); ++i) {
        if (QString::fromStdString(messages[i].name) == name) {
            messageIndex = i;
            break;
        }
    }

    if (messageIndex == -1) {
        qWarning() << "Message not found:" << name;
        return QString("00 00 00 00 00 00 00 00");
    }

    const auto& msg = messages[messageIndex];
    
    // Create a buffer of zeros for the CAN frame data
    std::vector<uint8_t> frameData(msg.length, 0);

    // Pack the signal values into the frame data
    for (const auto& signal : msg.signalList) {
        if (signal.value == 0.0) continue; // Skip zero values for efficiency

        // Calculate raw value from physical value
        double rawValue = (signal.value - signal.offset) / signal.factor;
        uint64_t intValue = static_cast<uint64_t>(std::round(rawValue));

        // Ensure the value fits within the signal's bit length
        uint64_t maxValue = (1ULL << signal.length) - 1;
        if (intValue > maxValue) {
            intValue = maxValue;
        }

        // Pack the bits into the frame data
        for (int bit = 0; bit < signal.length; ++bit) {
            int bitPosition;
            if (signal.littleEndian) {
                bitPosition = signal.startBit + bit;
            } else {
                // Motorola (big-endian) bit ordering
                bitPosition = signal.startBit - bit;
            }

            int byteIndex = bitPosition / 8;
            int bitInByte = bitPosition % 8;

            if (byteIndex >= 0 && byteIndex < static_cast<int>(frameData.size())) {
                if (intValue & (1ULL << bit)) {
                    frameData[byteIndex] |= (1 << bitInByte);
                }
            }
        }
    }

    // Convert to hex string
    QStringList hexBytes;
    for (uint8_t byte : frameData) {
        hexBytes << QString("%1").arg(byte, 2, 16, QChar('0')).toUpper();
    }

    return hexBytes.join(" ");
}

unsigned long DbcParser::getMessageId(const QString &messageName)
{
    // Extract the message name without the ID part
    int parenthesisPos = messageName.indexOf(" (");
    QString name = parenthesisPos > 0 ? messageName.left(parenthesisPos) : messageName;

    for (const auto& msg : messages) {
        if (QString::fromStdString(msg.name) == name) {
            return msg.id;
        }
    }

    return 0;
}

bool DbcParser::sendCanMessage(const QString &messageName, int rateMs)
{
    // Check if we have a dbcSender instance
    if (!dbcSender) {
        qWarning() << "DbcSender not initialized";
        emit messageSendStatus(messageName, false, "Error: DbcSender not initialized");
        return false;
    }

    // Stop any existing transmission for this message first
    if (stopExistingTransmission(messageName)) {
        qDebug() << "Stopped existing transmission for message:" << messageName << "before starting new one";
        emit showInfo("Replaced existing transmission for message: " + messageName);
    }

    QString messageData = prepareCanMessage(messageName, rateMs);
    if (messageData.isEmpty()) {
        qWarning() << "Failed to prepare message:" << messageName;
        emit messageSendStatus(messageName, false, "Error: Failed to prepare message");
        return false;
    }

    // Emit starting status
    emit messageSendStatus(messageName, true, "Sending message...");

    // Send the message via DbcSender
    qint8 result = dbcSender->sendCANMessage(messageData);
    
    if (result == 0) {
        qDebug() << "Successfully sent CAN message:" << messageData;
        
        // Get the task ID from the server response
        QString taskId = dbcSender->getLastTaskId();
        
        // Add this transmission to active transmissions
        addActiveTransmission(messageName, rateMs, taskId);
        
        emit messageSendStatus(messageName, true, "Message sent successfully!");
        return true;
    } else if (result == 2) {
        // Error code 2 is typically a timeout waiting for acknowledgment
        // The message was likely sent successfully but no response received
        qDebug() << "Message sent but no acknowledgment received:" << messageData;
        
        // Get the task ID from the server response
        QString taskId = dbcSender->getLastTaskId();
        
        // Still add to active transmissions since it was likely sent
        addActiveTransmission(messageName, rateMs, taskId);
        
        emit messageSendStatus(messageName, true, "Message transmitted (no acknowledgment received)");
        return true; // Consider this a success since message was transmitted
    } else {
        QString errorMsg = QString("Send failed with error code: %1").arg(result);
        qWarning() << "Failed to send CAN message. Error code:" << result;
        emit messageSendStatus(messageName, false, errorMsg);
        return false;
    }
}

bool DbcParser::sendCanMessage(const QString &messageName, int rateMs, const QString &canBus)
{
    qDebug() << "Send CAN message called for:" << messageName << "rate:" << rateMs << "ms on bus:" << canBus;
    
    emit messageSendStatus(messageName, true, "Sending message...");
    
    return startTransmission(messageName, rateMs, canBus);
}

bool DbcParser::sendCanMessageOnce(const QString &messageName, const QString &canBus)
{
    qDebug() << "Send CAN message once called for:" << messageName << "on bus:" << canBus;
    
    // Check if we have a dbcSender instance
    if (!dbcSender) {
        qWarning() << "DbcSender not initialized";
        emit messageSendStatus(messageName, false, "Error: DbcSender not initialized");
        return false;
    }

    // Check if connected to server
    if (!dbcSender->isConnected()) {
        qDebug() << "Error: Not connected to server";
        emit messageSendStatus(messageName, false, "Error: Not connected to server");
        return false;
    }

    // Prepare the CAN message for one-shot sending
    // Use rate 0 since it's a one-shot message
    QString messageData = prepareCanMessage(messageName, 0, canBus);
    if (messageData.isEmpty()) {
        qWarning() << "Failed to prepare one-shot message:" << messageName;
        emit messageSendStatus(messageName, false, "Error: Failed to prepare message");
        return false;
    }

    // Emit starting status
    emit messageSendStatus(messageName, true, "Sending message once...");

    // Send the one-shot message via DbcSender using the new sendOneShotMessage method
    qint8 result = dbcSender->sendOneShotMessage(messageData, 0); // 0ms delay
    
    if (result == 0) {
        qDebug() << "Successfully sent one-shot CAN message:" << messageData;
        
        // Get the task ID from the server response (for logging/debugging)
        QString taskId = dbcSender->getLastTaskId();
        qDebug() << "One-shot message task ID:" << taskId;
        
        // Add to one-shot message history
        OneShotMessage oneShotMsg;
        oneShotMsg.messageName = messageName;
        oneShotMsg.messageId = getMessageId(messageName);
        oneShotMsg.hexData = getMessageHexData(messageName);
        oneShotMsg.sentAt = QDateTime::currentDateTime();
        oneShotMsg.canBus = canBus.isEmpty() ? "vcan0" : canBus;
        
        // Add to beginning of list (most recent first)
        m_oneShotMessages.prepend(oneShotMsg);
        
        // Limit history to 50 messages
        if (m_oneShotMessages.size() > 50) {
            m_oneShotMessages.removeLast();
        }
        
        emit oneShotMessagesChanged();
        emit messageSendStatus(messageName, true, "Message sent once successfully!");
        return true;
    } else if (result == 2) {
        // Error code 2 is typically a timeout waiting for acknowledgment
        // The message was likely sent successfully but no response received
        qDebug() << "One-shot message sent but no acknowledgment received:" << messageData;
        
        // Add to one-shot message history even with no acknowledgment
        OneShotMessage oneShotMsg;
        oneShotMsg.messageName = messageName;
        oneShotMsg.messageId = getMessageId(messageName);
        oneShotMsg.hexData = getMessageHexData(messageName);
        oneShotMsg.sentAt = QDateTime::currentDateTime();
        oneShotMsg.canBus = canBus.isEmpty() ? "vcan0" : canBus;
        
        // Add to beginning of list (most recent first)
        m_oneShotMessages.prepend(oneShotMsg);
        
        // Limit history to 50 messages
        if (m_oneShotMessages.size() > 50) {
            m_oneShotMessages.removeLast();
        }
        
        emit oneShotMessagesChanged();
        emit messageSendStatus(messageName, true, "Message sent once (no acknowledgment received)");
        return true; // Consider this a success since message was transmitted
    } else {
        QString errorMsg = QString("One-shot send failed with error code: %1").arg(result);
        qWarning() << "Failed to send one-shot CAN message. Error code:" << result;
        emit messageSendStatus(messageName, false, errorMsg);
        return false;
    }
}

// Start transmission with CAN bus parameter
bool DbcParser::startTransmission(const QString &messageName, int rateMs, const QString &canBus)
{
    qDebug() << "Starting transmission for message:" << messageName << "rate:" << rateMs << "ms on bus:" << canBus;

    // Stop any existing transmission for this message on the same CAN bus only
    stopExistingTransmission(messageName, canBus);

    if (!dbcSender || !dbcSender->isConnected()) {
        qDebug() << "Error: Not connected to server";
        emit messageSendStatus(messageName, false, "Error: Not connected to server");
        return false;
    }

    // Prepare the CAN message with the specified bus
    QString canMessage = prepareCanMessage(messageName, rateMs, canBus);
    if (canMessage.isEmpty()) {
        qDebug() << "Error: Failed to prepare CAN message";
        emit messageSendStatus(messageName, false, "Error: Failed to prepare CAN message");
        return false;
    }

    // Send the message
    qint8 result = dbcSender->sendCANMessage(canMessage);
    if (result == 0) {
        // Get the task ID from the sender
        QString taskId = dbcSender->getLastTaskId();
        
        // Add to active transmissions
        addActiveTransmission(messageName, taskId, rateMs, canBus);
        
        qDebug() << "Message transmission started successfully with task ID:" << taskId;
        emit messageSendStatus(messageName, true, "Message transmission started");
        emit activeTransmissionsChanged();
        return true;
    } else {
        qDebug() << "Error: Failed to send CAN message, error code:" << result;
        emit messageSendStatus(messageName, false, "Error: Failed to send CAN message");
        return false;
    }
}

// Helper method to add active transmission with canBus parameter
void DbcParser::addActiveTransmission(const QString &messageName, const QString &taskId, int rateMs, const QString &canBus)
{
    ActiveTransmission transmission;
    transmission.messageName = messageName;
    transmission.taskId = taskId;
    transmission.rateMs = rateMs;
    transmission.isPaused = false;
    transmission.status = "Active";
    transmission.lastSent = QDateTime::currentDateTime().toString("hh:mm:ss");
    transmission.sentCount = 0;
    transmission.startedAt = QDateTime::currentDateTime();
    transmission.canBus = canBus.isEmpty() ? "vcan0" : canBus;
    
    // Get message details
    for (const auto &msg : messages) {
        if (QString::fromStdString(msg.name) == messageName) {
            transmission.messageId = msg.id;
            transmission.hexData = getMessageHexData(messageName);
            break;
        }
    }
    
    m_activeTransmissions.append(transmission);
    qDebug() << "Added active transmission:" << messageName << "with task ID:" << taskId << "on bus:" << canBus;
}



// Get available CAN interfaces
QStringList DbcParser::getAvailableCanInterfaces()
{
    qDebug() << "Getting available CAN interfaces";
    
    if (!dbcSender) {
        qDebug() << "Error: DbcSender not available";
        return QStringList() << "vcan0"; // Default fallback
    }
    
    QString response = dbcSender->listCanInterfaces();
    if (response.isEmpty() || response.startsWith("Error:")) {
        qDebug() << "Error getting CAN interfaces:" << response;
        return QStringList() << "vcan0"; // Default fallback
    }
    
    // Parse the response to extract CAN interface names
    QStringList interfaces;
    QStringList lines = response.split('\n', Qt::SkipEmptyParts);
    
    for (const QString &line : lines) {
        QString trimmed = line.trimmed();
        if (!trimmed.isEmpty() && !trimmed.startsWith("Available") && !trimmed.startsWith("CAN")) {
            // Assume each line contains an interface name
            interfaces.append(trimmed);
        }
    }
    
    if (interfaces.isEmpty()) {
        qDebug() << "No CAN interfaces found in response, using default";
        interfaces.append("vcan0");
    }
    
    qDebug() << "Available CAN interfaces:" << interfaces;
    return interfaces;
}

// Unified method to get hex data for the currently selected message
QString DbcParser::getCurrentMessageHexData()
{
    if (selectedMessageIndex < 0 || selectedMessageIndex >= static_cast<int>(messages.size())) {
        return QString("00 00 00 00 00 00 00 00");
    }
    
    const auto& msg = messages[selectedMessageIndex];
    
    // Create a buffer of zeros for the CAN frame data
    std::vector<uint8_t> frameData(msg.length, 0);

    // Pack the signal values into the frame data
    for (const auto& signal : msg.signalList) {
        if (signal.value == 0.0) continue; // Skip zero values for efficiency

        // Calculate raw value from physical value
        double rawValue = (signal.value - signal.offset) / signal.factor;
        uint64_t intValue = static_cast<uint64_t>(std::round(rawValue));

        // Ensure the value fits within the signal's bit length
        uint64_t maxValue = (1ULL << signal.length) - 1;
        if (intValue > maxValue) {
            intValue = maxValue;
        }

        // Pack the bits into the frame data
        for (int bit = 0; bit < signal.length; ++bit) {
            int bitPosition;
            if (signal.littleEndian) {
                bitPosition = signal.startBit + bit;
            } else {
                // Motorola (big-endian) bit ordering
                bitPosition = signal.startBit - bit;
            }

            int byteIndex = bitPosition / 8;
            int bitInByte = bitPosition % 8;

            if (byteIndex >= 0 && byteIndex < static_cast<int>(frameData.size())) {
                if (intValue & (1ULL << bit)) {
                    frameData[byteIndex] |= (1 << bitInByte);
                }
            }
        }
    }

    // Convert to hex string
    QStringList hexBytes;
    for (uint8_t byte : frameData) {
        hexBytes << QString("%1").arg(byte, 2, 16, QChar('0')).toUpper();
    }

    return hexBytes.join(" ");
}

// Unified method to get binary data for the currently selected message
QString DbcParser::getCurrentMessageBinData()
{
    if (selectedMessageIndex < 0 || selectedMessageIndex >= static_cast<int>(messages.size())) {
        return QString("00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000");
    }

    // Get the current message
    const canMessage& msg = messages[selectedMessageIndex];
    
    // Build binary representation
    QStringList binBytes;
    for (int i = 0; i < msg.length; i++) {
        binBytes << "00000000"; // Default to all zeros
    }
    
    // Apply signal values to generate the actual binary data
    for (const auto& signal : msg.signalList) {
        // Convert signal value to raw binary value
        uint64_t rawValue = static_cast<uint64_t>((signal.value - signal.offset) / signal.factor);
        
        // Apply the raw value to the appropriate bits in the message
        for (int bit = 0; bit < signal.length; bit++) {
            int bitPos;
            if (signal.littleEndian) {
                bitPos = signal.startBit + bit;
            } else {
                // Motorola (big-endian) bit numbering
                bitPos = signal.startBit - bit;
            }
            
            if (bitPos >= 0 && bitPos < msg.length * 8) {
                int byteIndex = bitPos / 8;
                int bitIndex = 7 - (bitPos % 8);
                
                if (byteIndex < binBytes.size()) {
                    QString byteStr = binBytes[byteIndex];
                    if (rawValue & (1ULL << bit)) {
                        byteStr[bitIndex] = '1';
                    } else {
                        byteStr[bitIndex] = '0';
                    }
                    binBytes[byteIndex] = byteStr;
                }
            }
        }
    }
    
    return binBytes.join(" ");
}

// Transmission management methods
bool DbcParser::stopExistingTransmission(const QString &messageName)
{
    // This method stops ALL transmissions for the given message name (regardless of CAN bus)
    // Use this when you want to stop all instances of a message across all buses
    return stopExistingTransmission(messageName, QString()); // Empty string means all buses
}

bool DbcParser::stopExistingTransmission(const QString &messageName, const QString &canBus)
{
    // Extract the clean message name (remove ID part if present)
    int parenthesisPos = messageName.indexOf(" (");
    QString cleanMessageName = parenthesisPos > 0 ? messageName.left(parenthesisPos) : messageName;
    
    bool foundAndStopped = false;
    
    for (auto it = m_activeTransmissions.begin(); it != m_activeTransmissions.end(); ++it) {
        // Extract clean name from existing transmission
        int existingParenthesisPos = it->messageName.indexOf(" (");
        QString existingCleanName = existingParenthesisPos > 0 ? it->messageName.left(existingParenthesisPos) : it->messageName;
        
        // Check if message name matches
        bool messageMatches = (existingCleanName == cleanMessageName);
        
        // Check if CAN bus matches (empty canBus means match all buses)
        bool busMatches = canBus.isEmpty() || (it->canBus == canBus);
        
        if (messageMatches && busMatches) {
            qDebug() << "Found existing transmission for message:" << cleanMessageName 
                     << "on bus:" << it->canBus << "- stopping it";
            
            // Stop the transmission on the server
            if (dbcSender && isConnectedToServer() && !it->taskId.isEmpty()) {
                qDebug() << "Stopping server task:" << it->taskId << "for message:" << it->messageName;
                dbcSender->stopCANMessage(it->taskId);
            }
            
            QString stoppedMessageName = it->messageName;
            emit transmissionStatusChanged(stoppedMessageName, "Stopped");
            
            // Add to past transmissions before removing from active list
            addToPastTransmissions(*it, "Stopped");
            
            // Remove from active list
            m_activeTransmissions.erase(it);
            foundAndStopped = true;
            
            qDebug() << "Successfully stopped existing transmission for:" << cleanMessageName 
                     << "on bus:" << (canBus.isEmpty() ? "all buses" : canBus);
            
            // If we're looking for a specific bus, stop after first match
            // If canBus is empty (all buses), continue to remove all matches
            if (!canBus.isEmpty()) {
                break;
            }
            // Reset iterator since we modified the container
            it = m_activeTransmissions.begin();
            if (it == m_activeTransmissions.end()) {
                break;
            }
            --it; // Will be incremented by for loop
        }
    }
    
    if (foundAndStopped) {
        updateActiveTransmissions();
    }
    
    return foundAndStopped;
}

void DbcParser::addActiveTransmission(const QString &messageName, int rateMs, const QString &taskId)
{
    qDebug() << "Adding active transmission for message:" << messageName << "with rate:" << rateMs << "and taskId:" << taskId;

    // Extract the message name without the ID part (e.g., "SimpBMS_Status (0x356)" -> "SimpBMS_Status")
    int parenthesisPos = messageName.indexOf(" (");
    QString cleanMessageName = parenthesisPos > 0 ? messageName.left(parenthesisPos) : messageName;
    
    // Find the message in DBC data
    auto messageIt = std::find_if(messages.begin(), messages.end(),
        [&cleanMessageName](const canMessage& msg) {
            return QString::fromStdString(msg.name) == cleanMessageName;
        });

    if (messageIt == messages.end()) {
        emit showError("Message '" + messageName + "' not found in DBC file");
        qWarning() << "Message not found:" << messageName;
        return;
    }

    // Create new active transmission
    ActiveTransmission newTransmission;
    newTransmission.messageName = messageName;
    newTransmission.messageId = messageIt->id;
    newTransmission.taskId = taskId;
    newTransmission.rateMs = rateMs;
    newTransmission.isPaused = false;
    newTransmission.status = "Active";
    newTransmission.lastSent = QDateTime::currentDateTime().toString("hh:mm:ss");
    newTransmission.sentCount = 1; // First message has been sent
    newTransmission.startedAt = QDateTime::currentDateTime();
    newTransmission.hexData = getMessageHexData(messageName);

    m_activeTransmissions.append(newTransmission);
    
    qDebug() << "Added new active transmission for:" << messageName << "with taskId:" << taskId;
    updateActiveTransmissions();
    emit transmissionStatusChanged(messageName, "Active");
}



// Missing transmission control methods

bool DbcParser::killAllTransmissions()
{
    qDebug() << "Kill all transmissions called";
    return stopAllTransmissions();
}

bool DbcParser::stopAllTransmissions()
{
    qDebug() << "Stop all transmissions called";
    
    if (!dbcSender || !dbcSender->isConnected()) {
        return false;
    }
    
    // Add all active transmissions to past transmissions before clearing
    for (const auto& transmission : m_activeTransmissions) {
        addToPastTransmissions(transmission, "Killed All");
    }
    
    qint8 result = dbcSender->killAllTasks();
    if (result == 0) {
        clearActiveTransmissions();
        return true;
    }
    return false;
}

bool DbcParser::pauseAllTransmissions()
{
    qDebug() << "Pause all transmissions called";
    
    bool success = true;
    for (auto &transmission : m_activeTransmissions) {
        if (!pauseTransmission(transmission.messageName)) {
            success = false;
        }
    }
    return success;
}

bool DbcParser::resumeAllTransmissions()
{
    qDebug() << "Resume all transmissions called";
    
    bool success = true;
    for (auto &transmission : m_activeTransmissions) {
        if (transmission.isPaused && !resumeTransmission(transmission.messageName)) {
            success = false;
        }
    }
    return success;
}

// Missing method implementations for linker errors

void DbcParser::setTcpClient(QObject* tcpClient)
{
    qDebug() << "Set TCP client called";
    if (dbcSender) {
        dbcSender->setProperty("tcpClient", QVariant::fromValue(tcpClient));
    }
}

QString DbcParser::testConfigLoad()
{
    qDebug() << "Test config load called";
    return "Test config load not implemented";
}

bool DbcParser::connectToServer(const QString &address, const QString &port)
{
    qDebug() << "Connect to server called with address:" << address << "port:" << port;
    
    if (!dbcSender) {
        qDebug() << "Error: DbcSender not available";
        return false;
    }
    
    qint8 result = dbcSender->initiateConnection(address, port);
    if (result == 0) {
        qDebug() << "Successfully connected to server";
        emit connectionStatusChanged();
        return true;
    } else {
        qDebug() << "Failed to connect to server, error code:" << result;
        emit connectionStatusChanged();
        return false;
    }
}

QString DbcParser::debugLoadConfig(const QUrl &url)
{
    qDebug() << "Debug load config called with URL:" << url;
    return "Debug load config not implemented";
}

QStringList DbcParser::getConfigSummary(const QUrl &url)
{
    qDebug() << "Get config summary called with URL:" << url;
    return QStringList() << "Config summary not implemented";
}

bool DbcParser::stopTransmission(const QString &messageName)
{
    qDebug() << "Stop transmission called for:" << messageName;
    return stopExistingTransmission(messageName);
}

bool DbcParser::pauseTransmission(const QString &messageName)
{
    qDebug() << "Pause transmission called for:" << messageName;
    
    if (!dbcSender || !dbcSender->isConnected()) {
        return false;
    }
    
    // Find the transmission and pause it
    for (auto &transmission : m_activeTransmissions) {
        if (transmission.messageName == messageName) {
            qint8 result = dbcSender->pauseCANMessage(transmission.taskId);
            if (result == 0) {
                transmission.isPaused = true;
                transmission.status = "Paused";
                emit activeTransmissionsChanged();
                emit transmissionStatusChanged(messageName, "Paused");
                return true;
            }
        }
    }
    return false;
}

bool DbcParser::startTransmission(const QString &messageName, int rateMs)
{
    qDebug() << "Start transmission called for:" << messageName << "rate:" << rateMs;
    return startTransmission(messageName, rateMs, "vcan0"); // Use default CAN bus
}

bool DbcParser::resumeTransmission(const QString &messageName)
{
    qDebug() << "Resume transmission called for:" << messageName;
    
    if (!dbcSender || !dbcSender->isConnected()) {
        return false;
    }
    
    // Find the transmission and resume it
    for (auto &transmission : m_activeTransmissions) {
        if (transmission.messageName == messageName && transmission.isPaused) {
            qint8 result = dbcSender->resumeCANMessage(transmission.taskId);
            if (result == 0) {
                transmission.isPaused = false;
                transmission.status = "Active";
                emit activeTransmissionsChanged();
                emit transmissionStatusChanged(messageName, "Active");
                return true;
            }
        }
    }
    return false;
}

bool DbcParser::validateConfigFile(const QUrl &fileUrl)
{
    qDebug() << "Validate config file called with URL:" << fileUrl;
    return false;
}

void DbcParser::disconnectFromServer()
{
    qDebug() << "Disconnect from server called";
    
    if (dbcSender) {
        // Stop all active transmissions first
        qDebug() << "Stopping all transmissions before disconnect";
        killAllTransmissions();
        
        // Clear active transmissions list
        m_activeTransmissions.clear();
        emit activeTransmissionsChanged();
        
        // Disconnect from server
        dbcSender->disconnect();
        emit connectionStatusChanged();
        
        qDebug() << "Successfully disconnected from server";
    }
}

void DbcParser::refreshTasksFromClient()
{
    qDebug() << "Refresh tasks from client called";
    updateActiveTransmissions();
}

bool DbcParser::stopActiveTransmission(unsigned int messageId)
{
    qDebug() << "Stop active transmission called for message ID:" << messageId;
    
    for (int i = 0; i < m_activeTransmissions.size(); ++i) {
        if (m_activeTransmissions[i].messageId == messageId) {
            return stopTransmission(m_activeTransmissions[i].messageName);
        }
    }
    
    qDebug() << "No active transmission found for message ID:" << messageId;
    return false;
}

bool DbcParser::pauseActiveTransmission(unsigned int messageId)
{
    qDebug() << "Pause active transmission called for message ID:" << messageId;
    
    for (int i = 0; i < m_activeTransmissions.size(); ++i) {
        if (m_activeTransmissions[i].messageId == messageId) {
            return pauseTransmission(m_activeTransmissions[i].messageName);
        }
    }
    
    qDebug() << "No active transmission found for message ID:" << messageId;
    return false;
}

void DbcParser::clearActiveTransmissions()
{
    qDebug() << "Clearing active transmissions";
    m_activeTransmissions.clear();
    emit activeTransmissionsChanged();
}

bool DbcParser::resumeActiveTransmission(unsigned int messageId)
{
    qDebug() << "Resume active transmission called for message ID:" << messageId;
    
    for (int i = 0; i < m_activeTransmissions.size(); ++i) {
        if (m_activeTransmissions[i].messageId == messageId) {
            return resumeTransmission(m_activeTransmissions[i].messageName);
        }
    }
    
    qDebug() << "No active transmission found for message ID:" << messageId;
    return false;
}

void DbcParser::updateActiveTransmissions()
{
    qDebug() << "Update active transmissions called";
    
    if (!dbcSender || !dbcSender->isConnected()) {
        return;
    }
    
    // Get current tasks from server
    QString tasksResponse = dbcSender->listTasks();
    // TODO: Parse response and update transmission states
    
    emit activeTransmissionsChanged();
}

bool DbcParser::loadActiveTransmissionsConfig(const QUrl &loadUrl)
{
    QString filePath = loadUrl.toLocalFile();
    qDebug() << "Loading config - Original URL:" << loadUrl.toString();
    qDebug() << "Loading config - Local file path:" << filePath;
    
    // Check if DBC file is loaded first
    if (messages.empty()) {
        emit showError("Cannot load configuration: No DBC file is currently loaded. Please load a DBC file first.");
        qWarning() << "Cannot load config: No DBC file loaded";
        return false;
    }
    
    // Check if file path is valid
    if (filePath.isEmpty()) {
        emit showError("Invalid file path for loading configuration");
        qWarning() << "Invalid file path for loading active transmissions config";
        return false;
    }
    
    // Validate file exists and is readable
    QFileInfo fileInfo(filePath);
    if (!fileInfo.exists()) {
        emit showError("Active transmissions configuration file does not exist: " + fileInfo.fileName());
        qWarning() << "Active transmissions config file does not exist:" << filePath;
        return false;
    }
    
    if (!fileInfo.isReadable()) {
        emit showError("Cannot read active transmissions configuration file (permission denied): " + fileInfo.fileName());
        qWarning() << "Cannot read active transmissions config file (permissions):" << filePath;
        return false;
    }
    
    // Validate file extension (should be .json)
    if (fileInfo.suffix().compare("json", Qt::CaseInsensitive) != 0) {
        emit showError("Invalid file type. Active transmissions configuration files must have .json extension. Selected: " + fileInfo.fileName());
        qWarning() << "Invalid file extension for active transmissions config:" << fileInfo.suffix();
        return false;
    }

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        emit showError("Cannot read configuration file: " + QFileInfo(filePath).fileName());
        qWarning() << "Cannot read active transmissions config file:" << filePath;
        qWarning() << "File exists:" << QFile::exists(filePath);
        qWarning() << "File error:" << file.errorString();
        return false;
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
    
    if (parseError.error != QJsonParseError::NoError) {
        emit showError("Configuration file has invalid JSON format: " + parseError.errorString());
        qWarning() << "JSON parse error in config file:" << parseError.errorString();
        return false;
    }

    QJsonObject rootObj = doc.object();
    
    // Validate file type - check if this is actually an active transmissions config
    if (rootObj.contains("oneShotMessages")) {
        emit showError("This appears to be a One-Shot Messages configuration file, not an Active Transmissions configuration file. Please select the correct file type.");
        qWarning() << "Wrong file type: One-shot messages config loaded as active transmissions config";
        return false;
    }
    
    if (!rootObj.contains("activeTransmissions")) {
        emit showError("Invalid active transmissions configuration file: Missing 'activeTransmissions' data. Please select a valid active transmissions configuration file.");
        qWarning() << "Invalid active transmissions config: Missing activeTransmissions array";
        return false;
    }
    
    QString configVersion = rootObj["configVersion"].toString();
    QJsonArray transmissionsArray = rootObj["activeTransmissions"].toArray();

    qDebug() << "Loading active transmissions config version:" << configVersion;
    qDebug() << "Found" << transmissionsArray.size() << "transmission configurations";
    qDebug() << "Current DBC has" << messages.size() << "messages loaded";

    int loadedCount = 0;
    int skippedCount = 0;

    for (const QJsonValue& value : transmissionsArray) {
        QJsonObject transmissionObj = value.toObject();
        QString messageName = transmissionObj["messageName"].toString();
        int rateMs = transmissionObj["rateMs"].toInt();
        QString canBus = transmissionObj["canBus"].toString("vcan0"); // Default to vcan0 if not specified
        bool autoStart = transmissionObj["autoStart"].toBool();
        bool enabled = transmissionObj["enabled"].toBool(true); // Default to enabled
        
        // Validate the configuration
        if (messageName.isEmpty() || rateMs <= 0) {
            emit showWarning("Invalid configuration for transmission: " + messageName);
            qWarning() << "Invalid transmission config: messageName=" << messageName << "rateMs=" << rateMs;
            skippedCount++;
            continue;
        }
        
        // Check if message exists in current DBC
        if (!messageExists(messageName)) {
            emit showWarning("Message '" + messageName + "' not found in current DBC file - skipping");
            qWarning() << "Message" << messageName << "not found in current DBC - skipping";
            skippedCount++;
            continue;
        }
        
        // Check if transmission already active (now considering CAN bus)
        bool alreadyActive = false;
        for (const auto& existing : m_activeTransmissions) {
            // Extract clean name from existing transmission (remove ID part if present)
            int existingParenthesisPos = existing.messageName.indexOf(" (");
            QString existingCleanName = existingParenthesisPos > 0 ? existing.messageName.left(existingParenthesisPos) : existing.messageName;
            
            // Extract clean name from config message name
            int configParenthesisPos = messageName.indexOf(" (");
            QString configCleanName = configParenthesisPos > 0 ? messageName.left(configParenthesisPos) : messageName;
            
            if (existingCleanName == configCleanName && existing.canBus == canBus) {
                qDebug() << "Transmission for" << messageName << "on bus" << canBus << "already active - skipping";
                alreadyActive = true;
                skippedCount++;
                break;
            }
        }
        
        if (alreadyActive) continue;
        
        // Start transmission only if enabled and autoStart is true
        if (enabled && autoStart) {
            if (startTransmission(messageName, rateMs, canBus)) {
                loadedCount++;
                qDebug() << "Started transmission:" << messageName << "at" << rateMs << "ms on bus:" << canBus;
            } else {
                qWarning() << "Failed to start transmission:" << messageName << "on bus:" << canBus;
                skippedCount++;
            }
        } else {
            qDebug() << "Skipping transmission" << messageName << "on bus" << canBus << "(enabled:" << enabled << ", autoStart:" << autoStart << ")";
            skippedCount++;
        }
    }

    updateActiveTransmissions();
    
    qDebug() << "Configuration load complete. Loaded:" << loadedCount << "Skipped:" << skippedCount;
    
    if (loadedCount > 0) {
        emit showSuccess(QString("Configuration loaded successfully! Started %1 transmissions, skipped %2").arg(loadedCount).arg(skippedCount));
    } else if (skippedCount > 0) {
        emit showWarning(QString("Configuration loaded but no transmissions started. %1 items were skipped (possibly due to missing DBC messages or already active transmissions)").arg(skippedCount));
    } else {
        if (transmissionsArray.isEmpty()) {
            emit showError("Configuration file contains no transmission data. The file may be empty or corrupted.");
        } else {
            emit showError("No valid transmissions found in configuration file. Check that the DBC file contains the required messages and no transmissions are already active.");
        }
    }
    
    return loadedCount > 0; // Return true if at least one transmission was loaded
}

bool DbcParser::saveActiveTransmissionsConfig(const QUrl &saveUrl)
{
    QString filePath = saveUrl.toLocalFile();
    if (filePath.isEmpty()) {
        emit showError("Invalid file path for saving configuration");
        return false;
    }
    
    // Validate file extension
    QFileInfo fileInfo(filePath);
    if (fileInfo.suffix().compare("json", Qt::CaseInsensitive) != 0) {
        // Auto-add .json extension if missing
        if (fileInfo.suffix().isEmpty()) {
            filePath += ".json";
            fileInfo.setFile(filePath);
        }
    }
    
    // Check if we have any transmissions to save
    if (m_activeTransmissions.isEmpty()) {
        emit showError("No active transmissions to save. Start some transmissions first to create a configuration.");
        return false;
    }

    QJsonDocument doc;
    QJsonObject rootObj;
    QJsonArray transmissionsArray;

    for (const auto& transmission : m_activeTransmissions) {
        QJsonObject transmissionObj;
        transmissionObj["messageName"] = transmission.messageName;
        transmissionObj["messageId"] = static_cast<qint64>(transmission.messageId);
        transmissionObj["rateMs"] = transmission.rateMs;
        transmissionObj["hexData"] = transmission.hexData;
        transmissionObj["canBus"] = transmission.canBus; // Include CAN bus information
        
        // Configuration-specific settings (not runtime status)
        transmissionObj["description"] = QString("Auto-transmission for %1 every %2ms on %3").arg(transmission.messageName).arg(transmission.rateMs).arg(transmission.canBus);
        transmissionObj["autoStart"] = true; // Default to auto-start on load
        transmissionObj["enabled"] = true;   // Allow enabling/disabling without removing
        
        transmissionsArray.append(transmissionObj);
    }

    rootObj["activeTransmissions"] = transmissionsArray;
    rootObj["configVersion"] = "1.0";
    rootObj["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    rootObj["description"] = QString("Active transmission configuration saved with %1 transmissions").arg(transmissionsArray.size());
    
    doc.setObject(rootObj);

    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly)) {
        emit showError("Cannot write active transmissions configuration file: " + QFileInfo(filePath).fileName());
        qWarning() << "Cannot write active transmissions config to file:" << filePath;
        return false;
    }

    file.write(doc.toJson());
    file.close();
    qDebug() << "Saved active transmissions configuration to:" << filePath;
    emit showSuccess("Configuration saved successfully: " + QFileInfo(filePath).fileName());
    return true;
}

bool DbcParser::mergeActiveTransmissionsConfig(const QUrl &fileUrl, bool replaceExisting)
{
    qDebug() << "Merge active transmissions config called with URL:" << fileUrl << "replace:" << replaceExisting;
    return false;
}

QString DbcParser::getActiveTransmissionsConfigInfo(const QUrl &fileUrl)
{
    qDebug() << "Get active transmissions config info called with URL:" << fileUrl;
    return "Config info not implemented";
}

bool DbcParser::isDbcLoaded() const
{
    return !messages.empty();
}

QVariantList DbcParser::activeTransmissions() const
{
    QVariantList result;
    for (const auto &transmission : m_activeTransmissions) {
        QVariantMap map;
        map["messageName"] = transmission.messageName;
        map["messageId"] = QString("0x%1").arg(transmission.messageId, 0, 16).toUpper();
        map["taskId"] = transmission.taskId;
        map["rateMs"] = transmission.rateMs;
        map["isPaused"] = transmission.isPaused;
        map["status"] = transmission.status;
        map["lastSent"] = transmission.lastSent;
        map["sentCount"] = transmission.sentCount;
        map["hexData"] = transmission.hexData;
        map["startedAt"] = transmission.startedAt.toString("hh:mm:ss");
        map["canBus"] = transmission.canBus;
        result.append(map);
    }
    return result;
}

QStringList DbcParser::getAvailableMessages() const
{
    QStringList messageNames;
    for (const auto &message : messages) {
        messageNames.append(QString::fromStdString(message.name));
    }
    return messageNames;
}

// Helper method to move active transmission to past transmissions
void DbcParser::addToPastTransmissions(const ActiveTransmission& transmission, const QString& endReason)
{
    PastTransmission pastTx;
    pastTx.messageName = transmission.messageName;
    pastTx.messageId = transmission.messageId;
    pastTx.taskId = transmission.taskId;
    pastTx.rateMs = transmission.rateMs;
    pastTx.hexData = transmission.hexData;
    pastTx.startedAt = transmission.startedAt;
    pastTx.endedAt = QDateTime::currentDateTime();
    pastTx.endReason = endReason;
    pastTx.totalSent = transmission.sentCount;
    pastTx.canBus = transmission.canBus;
    
    // Calculate duration
    qint64 durationMs = pastTx.startedAt.msecsTo(pastTx.endedAt);
    if (durationMs < 1000) {
        pastTx.duration = QString("%1ms").arg(durationMs);
    } else if (durationMs < 60000) {
        pastTx.duration = QString("%1.%2s").arg(durationMs / 1000).arg((durationMs % 1000) / 100);
    } else {
        int seconds = durationMs / 1000;
        int minutes = seconds / 60;
        seconds = seconds % 60;
        pastTx.duration = QString("%1m %2s").arg(minutes).arg(seconds);
    }
    
    // Add to beginning of list (most recent first)
    m_pastTransmissions.prepend(pastTx);
    
    // Limit to 100 past transmissions
    if (m_pastTransmissions.size() > 100) {
        m_pastTransmissions.removeLast();
    }
    
    emit pastTransmissionsChanged();
}

// Property getters for new features
QVariantList DbcParser::pastTransmissions() const
{
    QVariantList list;
    for (const auto& transmission : m_pastTransmissions) {
        QVariantMap map;
        map["messageName"] = transmission.messageName;
        map["messageId"] = static_cast<qint64>(transmission.messageId);
        map["taskId"] = transmission.taskId;
        map["rateMs"] = transmission.rateMs;
        map["hexData"] = transmission.hexData;
        map["startedAt"] = transmission.startedAt;
        map["endedAt"] = transmission.endedAt;
        map["endReason"] = transmission.endReason;
        map["totalSent"] = transmission.totalSent;
        map["canBus"] = transmission.canBus;
        map["duration"] = transmission.duration;
        list.append(map);
    }
    return list;
}

QVariantList DbcParser::configFiles() const
{
    QVariantList list;
    for (const auto& config : m_configFiles) {
        QVariantMap map;
        map["fileName"] = config.fileName;
        map["filePath"] = config.filePath;
        map["lastModified"] = config.lastModified;
        map["description"] = config.description;
        map["messageCount"] = config.messageCount;
        list.append(map);
    }
    return list;
}

// Config file browser methods
void DbcParser::refreshConfigFiles()
{
    // Config file browser functionality is disabled
    // This method is kept for compatibility but does nothing
    m_configFiles.clear();
    emit configFilesChanged();
}

void DbcParser::setConfigDirectory(const QUrl &directoryUrl)
{
    // Config file browser functionality is disabled
    // This method is kept for compatibility but does nothing
    Q_UNUSED(directoryUrl)
}

bool DbcParser::loadConfigByFileName(const QString &fileName)
{
    // Config file browser functionality is disabled
    // This method is kept for compatibility but does nothing
    Q_UNUSED(fileName)
    qWarning() << "Config file browser functionality is disabled. Use File menu to load configs.";
    return false;
}

QString DbcParser::getConfigFileInfo(const QString &fileName)
{
    // Config file browser functionality is disabled
    Q_UNUSED(fileName)
    return "Config file browser functionality is disabled. Use File menu to manage configs.";
}

// Past transmissions methods
void DbcParser::clearPastTransmissions()
{
    qDebug() << "Clearing past transmissions";
    m_pastTransmissions.clear();
    emit pastTransmissionsChanged();
}

QVariantList DbcParser::getPastTransmissionsFiltered(const QString &filter)
{
    if (filter.isEmpty()) {
        return pastTransmissions();
    }
    
    QVariantList filteredList;
    QString lowerFilter = filter.toLower();
    
    for (const auto& transmission : m_pastTransmissions) {
        bool matches = transmission.messageName.toLower().contains(lowerFilter) ||
                      transmission.endReason.toLower().contains(lowerFilter) ||
                      transmission.canBus.toLower().contains(lowerFilter);
        
        if (matches) {
            QVariantMap map;
            map["messageName"] = transmission.messageName;
            map["messageId"] = static_cast<qint64>(transmission.messageId);
            map["taskId"] = transmission.taskId;
            map["rateMs"] = transmission.rateMs;
            map["hexData"] = transmission.hexData;
            map["startedAt"] = transmission.startedAt;
            map["endedAt"] = transmission.endedAt;
            map["endReason"] = transmission.endReason;
            map["totalSent"] = transmission.totalSent;
            map["canBus"] = transmission.canBus;
            map["duration"] = transmission.duration;
            filteredList.append(map);
        }
    }
    
    return filteredList;
}

void DbcParser::exportPastTransmissions(const QUrl &saveUrl)
{
    QString filePath = saveUrl.toLocalFile();
    if (filePath.isEmpty()) {
        emit showError("Invalid file path for export");
        return;
    }
    
    QJsonArray transmissionsArray;
    for (const auto& transmission : m_pastTransmissions) {
        QJsonObject txObj;
        txObj["messageName"] = transmission.messageName;
        txObj["messageId"] = static_cast<qint64>(transmission.messageId);
        txObj["taskId"] = transmission.taskId;
        txObj["rateMs"] = transmission.rateMs;
        txObj["hexData"] = transmission.hexData;
        txObj["startedAt"] = transmission.startedAt.toString(Qt::ISODate);
        txObj["endedAt"] = transmission.endedAt.toString(Qt::ISODate);
        txObj["endReason"] = transmission.endReason;
        txObj["totalSent"] = transmission.totalSent;
        txObj["canBus"] = transmission.canBus;
        txObj["duration"] = transmission.duration;
        transmissionsArray.append(txObj);
    }
    
    QJsonObject rootObj;
    rootObj["exportedAt"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    rootObj["totalCount"] = transmissionsArray.size();
    rootObj["pastTransmissions"] = transmissionsArray;
    
    QJsonDocument doc(rootObj);
    
    QFile file(filePath);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(doc.toJson());
        file.close();
        emit showSuccess("Past transmissions exported successfully");
        qDebug() << "Exported" << m_pastTransmissions.size() << "past transmissions to" << filePath;
    } else {
        emit showError("Failed to export past transmissions: Cannot write to file");
        qWarning() << "Failed to export past transmissions to" << filePath;
    }
}

bool DbcParser::isConnectedToServer() const
{
    return dbcSender && dbcSender->isConnected();
}

// One-shot message implementations
bool DbcParser::sendRawCanMessage(const QString &messageId, const QString &hexData, const QString &canBus, const QString &messageName)
{
    qDebug() << "Send raw CAN message called with ID:" << messageId << "data:" << hexData << "bus:" << canBus << "name:" << messageName;
    
    if (!dbcSender) {
        qWarning() << "DbcSender not initialized";
        emit showError("Error: CAN sender not initialized. Please check your connection setup.");
        return false;
    }

    if (!dbcSender->isConnected()) {
        qDebug() << "Error: Not connected to server";
        emit showError("Error: Not connected to server");
        return false;
    }

    // Validate message ID is not empty
    if (messageId.trimmed().isEmpty()) {
        qWarning() << "Empty message ID provided";
        emit showError("Message ID cannot be empty");
        return false;
    }
    
    // Parse message ID - handle both hex (0x123) and decimal formats
    bool ok;
    unsigned long canId;
    QString trimmedMessageId = messageId.trimmed();
    if (trimmedMessageId.startsWith("0x", Qt::CaseInsensitive)) {
        canId = trimmedMessageId.mid(2).toULong(&ok, 16);
    } else {
        canId = trimmedMessageId.toULong(&ok, 16);
        if (!ok) {
            canId = trimmedMessageId.toULong(&ok, 10);
        }
    }
    
    if (!ok) {
        qWarning() << "Invalid message ID format:" << messageId;
        emit showError("Invalid message ID format: " + messageId);
        return false;
    }
    
    // Validate CAN ID range (supporting both 11-bit and 29-bit identifiers)
    if (canId > 0x1FFFFFFF) { // 29-bit CAN ID maximum
        qWarning() << "CAN ID out of range:" << canId << "(max: 0x1FFFFFFF)";
        emit showError(QString("CAN ID out of range: 0x%1 (maximum: 0x1FFFFFFF)").arg(canId, 0, 16).toUpper());
        return false;
    }

    // Validate and clean hex data (remove spaces and common separators)
    QString trimmedHexData = hexData.trimmed();
    if (trimmedHexData.isEmpty()) {
        qWarning() << "Empty hex data provided";
        emit showError("Hex data cannot be empty");
        return false;
    }
    
    QString cleanHexData = trimmedHexData;
    cleanHexData.remove(" ");
    cleanHexData.remove("-");  // Remove hyphens sometimes used as separators
    cleanHexData.remove(":");  // Remove colons sometimes used as separators
    cleanHexData.remove("\t"); // Remove tabs
    cleanHexData.remove("\n"); // Remove newlines
    
    // Final check after cleaning
    if (cleanHexData.isEmpty()) {
        qWarning() << "Hex data is empty after cleaning:" << hexData;
        emit showError("Hex data contains only separators and spaces");
        return false;
    }
    
    if (cleanHexData.length() % 2 != 0) {
        qWarning() << "Invalid hex data length (must be even number of characters):" << hexData;
        emit showError("Invalid hex data length: " + hexData + " (must be even number of characters)");
        return false;
    }
    
    if (cleanHexData.length() > 16) {
        qWarning() << "Hex data too long (max 8 bytes = 16 hex characters):" << hexData;
        emit showError("Hex data too long: " + hexData + " (maximum 8 bytes = 16 hex characters)");
        return false;
    }
    
    // Validate that all characters are valid hex digits
    QRegularExpression hexRegex("^[0-9A-Fa-f]+$");
    if (!hexRegex.match(cleanHexData).hasMatch()) {
        qWarning() << "Invalid hex data contains non-hex characters:" << hexData;
        emit showError("Invalid hex data: " + hexData + " (only 0-9, A-F characters allowed)");
        return false;
    }

    // Format message: "canid#canmessage#rate#canbus" (rate=0 for one-shot)
    QString busToUse = canBus.isEmpty() ? "vcan0" : canBus;
    QString messageData = QString("%1#%2#0#%3").arg(canId, 0, 16).arg(cleanHexData).arg(busToUse);
    
    qDebug() << "Sending one-shot raw message:" << messageData;

    // Send the one-shot message
    qint8 result = dbcSender->sendOneShotMessage(messageData, 0);
    
    if (result == 0 || result == 2) {
        qDebug() << "Successfully sent raw one-shot CAN message";
        
        // Add to one-shot message history
        OneShotMessage oneShotMsg;
        oneShotMsg.messageName = messageName.isEmpty() ? 
            QString("Raw Message (0x%1)").arg(canId, 0, 16).toUpper() : messageName;
        oneShotMsg.messageId = canId;
        oneShotMsg.hexData = hexData;
        oneShotMsg.sentAt = QDateTime::currentDateTime();
        oneShotMsg.canBus = busToUse;
        
        // Add to beginning of list (most recent first)
        m_oneShotMessages.prepend(oneShotMsg);
        
        // Limit history to 50 messages
        if (m_oneShotMessages.size() > 50) {
            m_oneShotMessages.removeLast();
        }
        
        emit oneShotMessagesChanged();
        
        // Log successful transmission details
        qDebug() << "Added message to one-shot history. Total messages in history:" << m_oneShotMessages.size();
        qDebug() << "Message details - Name:" << oneShotMsg.messageName << "ID:" << QString("0x%1").arg(oneShotMsg.messageId, 0, 16) << "Data:" << oneShotMsg.hexData << "Bus:" << oneShotMsg.canBus;
        
        if (result == 0) {
            emit showSuccess("Raw message sent successfully!");
        } else {
            emit showSuccess("Raw message sent (no acknowledgment received)");
        }
        return true;
    } else {
        QString errorMsg = QString("Send failed with error code: %1").arg(result);
        qWarning() << "Failed to send raw CAN message. Error code:" << result;
        emit showError(errorMsg);
        return false;
    }
}

QVariantList DbcParser::oneShotMessages() const
{
    QVariantList result;
    for (const auto &message : m_oneShotMessages) {
        QVariantMap map;
        map["messageName"] = message.messageName;
        map["messageId"] = QString("0x%1").arg(message.messageId, 0, 16).toUpper();
        map["hexData"] = message.hexData;
        map["sentAt"] = message.sentAt.toString("hh:mm:ss");
        map["sentAtFull"] = message.sentAt.toString("yyyy-MM-dd hh:mm:ss");
        map["canBus"] = message.canBus;
        result.append(map);
    }
    return result;
}

bool DbcParser::saveOneShotMessagesConfig(const QUrl &saveUrl)
{
    QString filePath = saveUrl.toLocalFile();
    if (filePath.isEmpty()) {
        emit showError("Invalid file path for saving one-shot messages configuration");
        return false;
    }
    
    // Validate file extension
    QFileInfo fileInfo(filePath);
    if (fileInfo.suffix().compare("json", Qt::CaseInsensitive) != 0) {
        // Auto-add .json extension if missing
        if (fileInfo.suffix().isEmpty()) {
            filePath += ".json";
            fileInfo.setFile(filePath);
        }
    }
    
    // Check if we have any messages to save
    if (m_oneShotMessages.isEmpty()) {
        emit showError("No one-shot messages to save. Send some messages first to create history.");
        return false;
    }

    QJsonDocument doc;
    QJsonObject rootObj;
    QJsonArray messagesArray;

    for (const auto& message : m_oneShotMessages) {
        QJsonObject messageObj;
        messageObj["messageName"] = message.messageName;
        messageObj["messageId"] = static_cast<qint64>(message.messageId);
        messageObj["hexData"] = message.hexData;
        messageObj["sentAt"] = message.sentAt.toString(Qt::ISODate);
        messageObj["canBus"] = message.canBus;
        messagesArray.append(messageObj);
    }

    rootObj["oneShotMessages"] = messagesArray;
    rootObj["configVersion"] = "1.0";
    rootObj["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    rootObj["description"] = QString("One-shot message history with %1 messages").arg(messagesArray.size());
    
    doc.setObject(rootObj);

    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly)) {
        emit showError("Cannot write one-shot messages configuration file: " + QFileInfo(filePath).fileName());
        qWarning() << "Cannot write one-shot messages config to file:" << filePath;
        return false;
    }

    file.write(doc.toJson());
    file.close();
    qDebug() << "Saved one-shot messages configuration to:" << filePath;
    emit showSuccess("One-shot messages configuration saved successfully: " + QFileInfo(filePath).fileName());
    return true;
}

bool DbcParser::loadOneShotMessagesConfig(const QUrl &loadUrl)
{
    QString filePath = loadUrl.toLocalFile();
    if (filePath.isEmpty()) {
        emit showError("Invalid file path for loading one-shot messages configuration");
        return false;
    }
    
    // Validate file exists and is readable
    QFileInfo fileInfo(filePath);
    if (!fileInfo.exists()) {
        emit showError("One-shot messages configuration file does not exist: " + fileInfo.fileName());
        qWarning() << "One-shot config file does not exist:" << filePath;
        return false;
    }
    
    if (!fileInfo.isReadable()) {
        emit showError("Cannot read one-shot messages configuration file (permission denied): " + fileInfo.fileName());
        qWarning() << "Cannot read one-shot config file (permissions):" << filePath;
        return false;
    }
    
    // Validate file extension (should be .json)
    if (fileInfo.suffix().compare("json", Qt::CaseInsensitive) != 0) {
        emit showError("Invalid file type. One-shot messages configuration files must have .json extension. Selected: " + fileInfo.fileName());
        qWarning() << "Invalid file extension for one-shot config:" << fileInfo.suffix();
        return false;
    }

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        emit showError("Cannot read one-shot messages configuration file: " + QFileInfo(filePath).fileName());
        qWarning() << "Cannot read one-shot messages config file:" << filePath;
        return false;
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
    
    if (parseError.error != QJsonParseError::NoError) {
        emit showError("One-shot messages configuration file has invalid JSON format: " + parseError.errorString());
        qWarning() << "JSON parse error in one-shot messages config file:" << parseError.errorString();
        return false;
    }

    QJsonObject rootObj = doc.object();
    
    // Validate file type - check if this is actually a one-shot messages config
    if (rootObj.contains("activeTransmissions")) {
        emit showError("This appears to be an Active Transmissions configuration file, not a One-Shot Messages configuration file. Please select the correct file type.");
        qWarning() << "Wrong file type: Active transmissions config loaded as one-shot config";
        return false;
    }
    
    if (!rootObj.contains("oneShotMessages")) {
        emit showError("Invalid one-shot messages configuration file: Missing 'oneShotMessages' data. Please select a valid one-shot messages configuration file.");
        qWarning() << "Invalid one-shot config: Missing oneShotMessages array";
        return false;
    }
    
    QString configVersion = rootObj["configVersion"].toString();
    QJsonArray messagesArray = rootObj["oneShotMessages"].toArray();

    qDebug() << "Loading one-shot messages config version:" << configVersion;
    qDebug() << "Found" << messagesArray.size() << "one-shot message records";
    
    // If no messages found, that's also an error condition
    if (messagesArray.isEmpty()) {
        emit showError("One-shot messages configuration file is empty or contains no valid messages.");
        qWarning() << "One-shot config file contains no messages";
        return false;
    }

    // Clear existing history and load from config
    m_oneShotMessages.clear();

    int validMessages = 0;
    int skippedMessages = 0;
    
    for (const QJsonValue& value : messagesArray) {
        if (!value.isObject()) {
            qWarning() << "Invalid message entry in config file - not an object, skipping";
            skippedMessages++;
            continue;
        }
        
        QJsonObject messageObj = value.toObject();
        
        OneShotMessage message;
        message.messageName = messageObj["messageName"].toString();
        message.messageId = static_cast<unsigned long>(messageObj["messageId"].toInteger());
        message.hexData = messageObj["hexData"].toString();
        message.sentAt = QDateTime::fromString(messageObj["sentAt"].toString(), Qt::ISODate);
        message.canBus = messageObj["canBus"].toString();
        
        // Validate the message data thoroughly
        if (message.messageName.isEmpty()) {
            qWarning() << "Invalid one-shot message: empty message name - skipping";
            skippedMessages++;
            continue;
        }
        
        if (message.hexData.isEmpty()) {
            qWarning() << "Invalid one-shot message: empty hex data - skipping";
            skippedMessages++;
            continue;
        }
        
        // Validate hex data format
        QString cleanHexData = message.hexData;
        cleanHexData.remove(" ");
        QRegularExpression hexRegex("^[0-9A-Fa-f]+$");
        if (cleanHexData.length() % 2 != 0 || !hexRegex.match(cleanHexData).hasMatch()) {
            qWarning() << "Invalid one-shot message: invalid hex data format" << message.hexData << "- skipping";
            skippedMessages++;
            continue;
        }
        
        // Validate CAN ID range
        if (message.messageId > 0x1FFFFFFF) {
            qWarning() << "Invalid one-shot message: CAN ID out of range" << message.messageId << "- skipping";
            skippedMessages++;
            continue;
        }
        
        // Validate timestamp
        if (!message.sentAt.isValid()) {
            qWarning() << "Invalid one-shot message: invalid timestamp - using current time";
            message.sentAt = QDateTime::currentDateTime();
        }
        
        // Set default CAN bus if empty
        if (message.canBus.isEmpty()) {
            message.canBus = "vcan0";
        }
        
        m_oneShotMessages.append(message);
        validMessages++;
    }

    emit oneShotMessagesChanged();
    
    qDebug() << "One-shot messages configuration load complete. Loaded:" << validMessages << "valid messages, skipped:" << skippedMessages << "invalid messages";
    
    if (validMessages == 0) {
        emit showError("No valid one-shot messages could be loaded from the configuration file.");
        return false;
    } else if (skippedMessages > 0) {
        emit showSuccess(QString("One-shot messages configuration loaded! Loaded %1 valid messages, skipped %2 invalid messages").arg(validMessages).arg(skippedMessages));
    } else {
        emit showSuccess(QString("One-shot messages configuration loaded successfully! Loaded %1 messages").arg(validMessages));
    }
    
    return true;
}

void DbcParser::clearOneShotMessageHistory()
{
    qDebug() << "Clearing one-shot message history";
    m_oneShotMessages.clear();
    emit oneShotMessagesChanged();
    emit showInfo("One-shot message history cleared");
}

