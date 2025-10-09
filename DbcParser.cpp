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
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QJsonArray>
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
    
    // Use a timer to automatically attempt connection after the GUI is fully loaded
    QTimer::singleShot(1000, this, [this]() {
        qDebug() << "DbcParser: Attempting automatic connection to CAN receiver...";
        bool connected = connectToServer("146.163.51.113", "8828");
        if (connected) {
            qDebug() << "DbcParser: Successfully connected to CAN receiver on startup";
        } else {
            qDebug() << "DbcParser: Failed to connect to CAN receiver on startup - receiver may not be running";
        }
    });
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
            // Update the specified parameter
            if (paramName == "startBit") {
                sig.startBit = value.toInt();
            }
            else if (paramName == "length") {
                sig.length = value.toInt();
            }
            else if (paramName == "factor") {
                sig.factor = value.toDouble();
            }
            else if (paramName == "offset") {
                sig.offset = value.toDouble();
            }
            else if (paramName == "min") {
                sig.min = value.toDouble();
            }
            else if (paramName == "max") {
                sig.max = value.toDouble();
            }
            else if (paramName == "unit") {
                sig.unit = value.toString().toStdString();
            }
            else if (paramName == "littleEndian") {
                sig.littleEndian = value.toBool();
            }
            else {
                // Unknown parameter
                return false;
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
    QString output;
    QTextStream stream(&output);

    for (const auto& msg : messages) {
        stream << QString("BO_ %1 %2: %3 Vector__XXX\n")
                      .arg(msg.id)
                      .arg(QString::fromStdString(msg.name))
                      .arg(msg.length);

        for (const auto& sig : msg.signalList) {
            QString endian = sig.littleEndian ? "1" : "0";
            stream << QString("   SG_ %1 : %2|%3@%4+ (%5,%6) [%7|%8] \"%9\" Vector__XXX\n")
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

        stream << "\n";
    }

    return output.trimmed();
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
    for (const auto& msg : messages) {
        if (QString::fromStdString(msg.name) == messageName) {
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
    
    // Check if signal name already exists in this message
    for (const auto& sig : targetMessage->signalList) {
        if (QString::fromStdString(sig.name) == signalName) {
            return "Signal name '" + signalName + "' already exists in message '" + messageName + "'";
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
    
    // Check for overlaps with existing signals
    for (const auto& sig : targetMessage->signalList) {
        bool overlap = false;
        QString conflictingSignal = QString::fromStdString(sig.name);
        
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
    // Extract the message name without the ID part
    int parenthesisPos = messageName.indexOf(" (");
    QString name = parenthesisPos > 0 ? messageName.left(parenthesisPos) : messageName;

    for (const auto& msg : messages) {
        if (QString::fromStdString(msg.name) == name) {
            // Get the message ID
            unsigned long canId = msg.id;

            // Generate the hex data for this message
            QString hexData = getMessageHexData(messageName);

            // Format: "CAN_ID#HEX_DATA#RATE_MS"
            return QString("0x%1#%2#%3").arg(canId, 0, 16).arg(hexData).arg(rateMs);
        }
    }

    return QString();
}

QString DbcParser::getMessageHexData(const QString &messageName)
{
    // Extract the message name without the ID part
    int parenthesisPos = messageName.indexOf(" (");
    QString name = parenthesisPos > 0 ? messageName.left(parenthesisPos) : messageName;

    // Find the message index
    int messageIndex = -1;
    for (size_t i = 0; i < messages.size(); i++) {
        if (QString::fromStdString(messages[i].name) == name) {
            messageIndex = static_cast<int>(i);
            break;
        }
    }

    if (messageIndex < 0 || messageIndex >= static_cast<int>(messages.size())) {
        return QString("00 00 00 00 00 00 00 00");
    }
    
    // If this is the currently selected message, use the unified method to ensure consistency
    if (messageIndex == selectedMessageIndex) {
        return getCurrentMessageHexData();
    }

    // For non-selected messages, use the stored signal values
    const auto& msg = messages[messageIndex];

    // Create a buffer of zeros for the CAN frame data  
    std::vector<uint8_t> frameData(msg.length, 0);

    // For each signal, pack its value into the frame using the SAME logic as buildCanFrame()
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
    
    // Format the frame data as a hex string WITHOUT "Data: " prefix (this is the key difference from buildCanFrame)
    std::stringstream ss;
    for (size_t i = 0; i < frameData.size(); i++) {
        ss << std::hex << std::uppercase << std::setw(2) << std::setfill('0') << static_cast<int>(frameData[i]);
        if (i < frameData.size() - 1) {
            ss << " ";
        }
    }

    return QString::fromStdString(ss.str());
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
        emit messageSendStatus(messageName, true, "Message sent successfully!");
        return true;
    } else if (result == 2) {
        // Error code 2 is typically a timeout waiting for acknowledgment
        // The message was likely sent successfully but no response received
        qDebug() << "Message sent but no acknowledgment received:" << messageData;
        emit messageSendStatus(messageName, true, "Message transmitted (no acknowledgment received)");
        return true; // Consider this a success since message was transmitted
    } else {
        QString errorMsg = QString("Send failed with error code: %1").arg(result);
        qWarning() << "Failed to send CAN message. Error code:" << result;
        emit messageSendStatus(messageName, false, errorMsg);
        return false;
    }
}

bool DbcParser::connectToServer(const QString &address, const QString &port)
{
    if (isConnectedToServer()) {
        qDebug() << "Already connected to server";
        return true;
    }

    qint8 result = dbcSender->initiateConenction(address, port);
    
    if (result == 0) {
        qDebug() << "Successfully connected to server at" << address << ":" << port;
        emit connectionStatusChanged(); // Emit signal to update UI
        return true;
    } else {
        qWarning() << "Failed to connect to server. Error code:" << result;
        emit connectionStatusChanged(); // Emit signal to update UI
        return false;
    }
}

void DbcParser::disconnectFromServer()
{
    // DbcSender doesn't have a disconnect method, so we'll rely on socket cleanup
    // when the object is destroyed or the connection times out
    qDebug() << "Disconnect requested - DbcSender will handle connection cleanup";
    emit connectionStatusChanged(); // Emit signal to update UI
}

bool DbcParser::isConnectedToServer() const
{
    return dbcSender && dbcSender->isConnected();
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
    
    // For each signal, pack its value into the frame using the SAME logic as buildCanFrame()
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
    
    // Format the frame data as a hex string WITHOUT "Data: " prefix
    std::stringstream ss;
    for (size_t i = 0; i < frameData.size(); i++) {
        ss << std::hex << std::uppercase << std::setw(2) << std::setfill('0') << static_cast<int>(frameData[i]);
        if (i < frameData.size() - 1) {
            ss << " ";
        }
    }
    
    return QString::fromStdString(ss.str());
}

// Unified method to get binary data for the currently selected message
QString DbcParser::getCurrentMessageBinData()
{
    if (selectedMessageIndex < 0 || selectedMessageIndex >= static_cast<int>(messages.size())) {
        return QString("00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000");
    }
    
    const auto& msg = messages[selectedMessageIndex];
    
    // Create a buffer of zeros for the CAN frame data
    std::vector<uint8_t> frameData(msg.length, 0);
    
    // For each signal, pack its value into the frame using the SAME logic as buildCanFrame()
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

// Active transmission management methods
QVariantList DbcParser::activeTransmissions() const
{
    QVariantList result;
    for (const auto& transmission : m_activeTransmissions) {
        QVariantMap transmissionMap;
        transmissionMap["messageName"] = transmission.messageName;
        transmissionMap["messageId"] = static_cast<qint64>(transmission.messageId);
        transmissionMap["rateMs"] = transmission.rateMs;
        transmissionMap["interval"] = transmission.rateMs;
        transmissionMap["isPaused"] = transmission.isPaused;
        transmissionMap["status"] = transmission.status;
        transmissionMap["lastSent"] = transmission.lastSent;
        transmissionMap["sentCount"] = transmission.sentCount;
        transmissionMap["hexData"] = transmission.hexData;
        transmissionMap["startedAt"] = transmission.startedAt;
        result.append(transmissionMap);
    }
    return result;
}

bool DbcParser::startTransmission(const QString &messageName, int rateMs)
{
    if (!isConnectedToServer()) {
        emit showError("Cannot start transmission: not connected to server");
        qWarning() << "Cannot start transmission: not connected to server";
        return false;
    }

    // Check if transmission already exists
    for (auto& transmission : m_activeTransmissions) {
        if (transmission.messageName == messageName) {
            if (transmission.status == "Stopped") {
                transmission.status = "Active";
                transmission.isPaused = false;
                transmission.rateMs = rateMs;
                transmission.startedAt = QDateTime::currentDateTime();
                
                // Start the actual transmission on the server
                if (dbcSender && isConnectedToServer()) {
                    QString messageData = prepareCanMessage(messageName, rateMs);
                    if (!messageData.isEmpty()) {
                        dbcSender->sendCANMessage(messageData);
                    }
                }
                
                updateActiveTransmissions();
                emit transmissionStatusChanged(messageName, "Active");
                return true;
            } else {
                qWarning() << "Transmission already active for message:" << messageName;
                return false;
            }
        }
    }

    // Find the message
    auto messageIt = std::find_if(messages.begin(), messages.end(),
        [&messageName](const canMessage& msg) {
            return QString::fromStdString(msg.name) == messageName;
        });

    if (messageIt == messages.end()) {
        emit showError("Message '" + messageName + "' not found in DBC file");
        qWarning() << "Message not found:" << messageName;
        return false;
    }

    // Create new active transmission
    ActiveTransmission newTransmission;
    newTransmission.messageName = messageName;
    newTransmission.messageId = messageIt->id;
    newTransmission.rateMs = rateMs;
    newTransmission.isPaused = false;
    newTransmission.status = "Active";
    newTransmission.lastSent = QDateTime::currentDateTime().toString("hh:mm:ss");
    newTransmission.sentCount = 0;
    newTransmission.startedAt = QDateTime::currentDateTime();
    newTransmission.hexData = getMessageHexData(messageName);

    m_activeTransmissions.append(newTransmission);

    // Start the actual transmission on the server
    if (dbcSender && isConnectedToServer()) {
        QString messageData = prepareCanMessage(messageName, rateMs);
        if (!messageData.isEmpty()) {
            dbcSender->sendCANMessage(messageData);
        }
    }
    
    updateActiveTransmissions();
    emit transmissionStatusChanged(messageName, "Active");
    return true;
}

bool DbcParser::stopTransmission(const QString &messageName)
{
    for (auto it = m_activeTransmissions.begin(); it != m_activeTransmissions.end(); ++it) {
        if (it->messageName == messageName) {
            // Stop the transmission on the server
            if (dbcSender && isConnectedToServer()) {
                dbcSender->stopCANMessage(QString::number(it->messageId));
            }
            
            it->status = "Stopped";
            QString messageName = it->messageName;
            emit transmissionStatusChanged(messageName, "Stopped");
            
            // Remove from active list
            m_activeTransmissions.erase(it);
            updateActiveTransmissions();
            return true;
        }
    }
   

    return false;
}

bool DbcParser::pauseTransmission(const QString &messageName)
{
    for (auto& transmission : m_activeTransmissions) {
        if (transmission.messageName == messageName) {
            transmission.isPaused = true;
            transmission.status = "Paused";
            
            // Pause the transmission on the server
            if (dbcSender && isConnectedToServer()) {
                dbcSender->pauseCANMessage(QString::number(transmission.messageId));
            }
            
            updateActiveTransmissions();
            emit transmissionStatusChanged(messageName, "Paused");
            return true;
        }
    }
    return false;
}

bool DbcParser::resumeTransmission(const QString &messageName)
{
    for (auto& transmission : m_activeTransmissions) {
        if (transmission.messageName == messageName && transmission.isPaused) {
            transmission.isPaused = false;
            transmission.status = "Active";
            
            // Resume the transmission on the server
            if (dbcSender && isConnectedToServer()) {
                QString messageData = prepareCanMessage(messageName, transmission.rateMs);
                if (!messageData.isEmpty()) {
                    dbcSender->sendCANMessage(messageData);
                }
            }
            
            updateActiveTransmissions();
            emit transmissionStatusChanged(messageName, "Active");
            return true;
        }
    }
    return false;
}

bool DbcParser::stopActiveTransmission(unsigned int messageId)
{
    for (auto it = m_activeTransmissions.begin(); it != m_activeTransmissions.end(); ++it) {
        if (it->messageId == messageId) {
            if (dbcSender && isConnectedToServer()) {
                dbcSender->stopCANMessage(QString::number(messageId));
            }
            
            it->status = "Stopped";
            QString messageName = it->messageName;
            emit transmissionStatusChanged(messageName, "Stopped");
            
            m_activeTransmissions.erase(it);
            updateActiveTransmissions();
            return true;
        }
    }
    return false;
}

bool DbcParser::pauseActiveTransmission(unsigned int messageId)
{
    for (auto& transmission : m_activeTransmissions) {
        if (transmission.messageId == messageId && transmission.status == "Active") {
            transmission.isPaused = true;
            transmission.status = "Paused";
            
            if (dbcSender && isConnectedToServer()) {
                dbcSender->pauseCANMessage(QString::number(messageId));
            }
            
            updateActiveTransmissions();
            emit transmissionStatusChanged(transmission.messageName, "Paused");
            return true;
        }
    }
    return false;
}

bool DbcParser::resumeActiveTransmission(unsigned int messageId)
{
    for (auto& transmission : m_activeTransmissions) {
        if (transmission.messageId == messageId && transmission.status == "Paused") {
            transmission.isPaused = false;
            transmission.status = "Active";
            
            if (dbcSender && isConnectedToServer()) {
                QString messageData = prepareCanMessage(transmission.messageName, transmission.rateMs);
                if (!messageData.isEmpty()) {
                    dbcSender->sendCANMessage(messageData);
                }
            }
            
            updateActiveTransmissions();
            emit transmissionStatusChanged(transmission.messageName, "Active");
            return true;
        }
    }
    return false;
}

bool DbcParser::stopAllTransmissions()
{
    bool allStopped = true;
    for (auto& transmission : m_activeTransmissions) {
        if (dbcSender && isConnectedToServer()) {
            dbcSender->stopCANMessage(QString::number(transmission.messageId));
        }
        transmission.status = "Stopped";
        emit transmissionStatusChanged(transmission.messageName, "Stopped");
    }
    
    m_activeTransmissions.clear();
    updateActiveTransmissions();
    return allStopped;
}

bool DbcParser::pauseAllTransmissions()
{
    bool allPaused = true;
    for (auto& transmission : m_activeTransmissions) {
        if (transmission.status == "Active") {
            transmission.isPaused = true;
            transmission.status = "Paused";
            
            if (dbcSender && isConnectedToServer()) {
                dbcSender->pauseCANMessage(QString::number(transmission.messageId));
            }
            emit transmissionStatusChanged(transmission.messageName, "Paused");
        }
    }
    
    updateActiveTransmissions();
    return allPaused;
}

bool DbcParser::resumeAllTransmissions()
{
    bool allResumed = true;
    for (auto& transmission : m_activeTransmissions) {
        if (transmission.status == "Paused") {
            transmission.isPaused = false;
            transmission.status = "Active";
            
            if (dbcSender && isConnectedToServer()) {
                QString messageData = prepareCanMessage(transmission.messageName, transmission.rateMs);
                if (!messageData.isEmpty()) {
                    dbcSender->sendCANMessage(messageData);
                } else {
                    allResumed = false;
                }
            }
            emit transmissionStatusChanged(transmission.messageName, "Active");
        }
    }
    
    updateActiveTransmissions();
    return allResumed;
}



void DbcParser::clearActiveTransmissions()
{
    // Stop all active transmissions first
    for (auto& transmission : m_activeTransmissions) {
        if (dbcSender && isConnectedToServer()) {
            dbcSender->stopCANMessage(QString::number(transmission.messageId));
        }
        emit transmissionStatusChanged(transmission.messageName, "Stopped");
    }
    
    m_activeTransmissions.clear();
    emit activeTransmissionsChanged();
}

void DbcParser::updateActiveTransmissions()
{
    // Emit signal to notify QML that the active transmissions list has changed
    emit activeTransmissionsChanged();
}

bool DbcParser::saveActiveTransmissionsConfig(const QUrl &fileUrl)
{
    QString filePath = fileUrl.toLocalFile();
    if (filePath.isEmpty()) {
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
        
        // Configuration-specific settings (not runtime status)
        transmissionObj["description"] = QString("Auto-transmission for %1 every %2ms").arg(transmission.messageName).arg(transmission.rateMs);
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
        qWarning() << "Cannot write active transmissions config to file:" << filePath;
        return false;
    }

    file.write(doc.toJson());
    file.close();
    qDebug() << "Saved active transmissions configuration to:" << filePath;
    return true;
}

bool DbcParser::loadActiveTransmissionsConfig(const QUrl &fileUrl)
{
    QString filePath = fileUrl.toLocalFile();
    qDebug() << "Loading config - Original URL:" << fileUrl.toString();
    qDebug() << "Loading config - Local file path:" << filePath;
    
    if (filePath.isEmpty()) {
        emit showError("Invalid file path for loading configuration");
        qWarning() << "Invalid file path for loading active transmissions config";
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
    QString configVersion = rootObj["configVersion"].toString();
    QJsonArray transmissionsArray = rootObj["activeTransmissions"].toArray();

    qDebug() << "Loading active transmissions config version:" << configVersion;
    qDebug() << "Found" << transmissionsArray.size() << "transmission configurations";
    qDebug() << "Current DBC has" << messages.size() << "messages loaded";

    // Don't clear existing transmissions - add to them or ask user
    // clearActiveTransmissions();

    int loadedCount = 0;
    int skippedCount = 0;

    for (const QJsonValue& value : transmissionsArray) {
        QJsonObject transmissionObj = value.toObject();
        QString messageName = transmissionObj["messageName"].toString();
        int rateMs = transmissionObj["rateMs"].toInt();
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
        
        // Check if transmission already active
        bool alreadyActive = false;
        for (const auto& existing : m_activeTransmissions) {
            if (existing.messageName == messageName) {
                qDebug() << "Transmission for" << messageName << "already active - skipping";
                alreadyActive = true;
                skippedCount++;
                break;
            }
        }
        
        if (alreadyActive) continue;
        
        // Start transmission only if enabled and autoStart is true
        if (enabled && autoStart) {
            if (startTransmission(messageName, rateMs)) {
                loadedCount++;
                qDebug() << "Started transmission:" << messageName << "at" << rateMs << "ms";
            } else {
                qWarning() << "Failed to start transmission:" << messageName;
                skippedCount++;
            }
        } else {
            qDebug() << "Skipping transmission" << messageName << "(enabled:" << enabled << ", autoStart:" << autoStart << ")";
            skippedCount++;
        }
    }

    updateActiveTransmissions();
    
    qDebug() << "Configuration load complete. Loaded:" << loadedCount << "Skipped:" << skippedCount;
    
    if (loadedCount > 0) {
        emit showSuccess(QString("Configuration loaded successfully! Started %1 transmissions, skipped %2").arg(loadedCount).arg(skippedCount));
    } else if (skippedCount > 0) {
        emit showWarning(QString("Configuration loaded but no transmissions started. %1 items were skipped").arg(skippedCount));
    } else {
        emit showError("No valid transmissions found in configuration file");
    }
    
    return loadedCount > 0; // Return true if at least one transmission was loaded
}

// Debug methods for troubleshooting
QStringList DbcParser::getAvailableMessages() const
{
    QStringList messageNames;
    for (const auto& msg : messages) {
        messageNames << QString::fromStdString(msg.name);
    }
    return messageNames;
}

QString DbcParser::debugLoadConfig(const QUrl &fileUrl)
{
    QString result = "Debug Config Load:\n";
    QString filePath = fileUrl.toLocalFile();
    
    result += QString("URL: %1\n").arg(fileUrl.toString());
    result += QString("Local Path: %1\n").arg(filePath);
    result += QString("File Exists: %1\n").arg(QFile::exists(filePath) ? "Yes" : "No");
    result += QString("DBC Messages Loaded: %1\n").arg(messages.size());
    
    if (!messages.empty()) {
        result += "Available Messages:\n";
        for (const auto& msg : messages) {
            result += QString("- %1 (ID: %2)\n").arg(QString::fromStdString(msg.name)).arg(msg.id);
        }
    }
    
    // Test 3: Check config file path
    QString configPath = QDir::currentPath() + "/simpbms_transmission_config.json";
    result += QString("\nConfig file path: %1\n").arg(configPath);
    result += QString("Config file exists: %1\n").arg(QFile::exists(configPath) ? "Yes" : "No");
    
    // Test 4: Try to load config
    if (QFile::exists(configPath)) {
        QUrl fileUrl = QUrl::fromLocalFile(configPath);
        result += QString("QUrl: %1\n").arg(fileUrl.toString());
        
        bool success = loadActiveTransmissionsConfig(fileUrl);
        result += QString("Load result: %1\n").arg(success ? "SUCCESS" : "FAILED");
        
        result += QString("Active transmissions count: %1\n").arg(m_activeTransmissions.size());
    }
    
    return result;
}

QString DbcParser::getActiveTransmissionsConfigInfo(const QUrl &fileUrl) {
    QString result = "Config Info:\n";
    
    QString filePath = fileUrl.toLocalFile();
    if (!QFile::exists(filePath)) {
        return "Error: File does not exist";
    }
    
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        return "Error: Cannot open file";
    }
    
    QByteArray data = file.readAll();
    file.close();
    
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);
    
    if (error.error != QJsonParseError::NoError) {
        return QString("Error: Invalid JSON - %1").arg(error.errorString());
    }
    
    QJsonObject root = doc.object();
    result += QString("Version: %1\n").arg(root["version"].toString());
    result += QString("Created: %1\n").arg(root["created"].toString());
    
    QJsonArray transmissions = root["active_transmissions"].toArray();
    result += QString("Transmissions: %1\n").arg(transmissions.size());
    
    return result;
}

bool DbcParser::validateConfigFile(const QUrl &fileUrl) {
    QString filePath = fileUrl.toLocalFile();
    if (!QFile::exists(filePath)) {
        emit showError("Config file does not exist");
        return false;
    }
    
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        emit showError("Cannot open config file");
        return false;
    }
    
    QByteArray data = file.readAll();
    file.close();
    
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);
    
    if (error.error != QJsonParseError::NoError) {
        emit showError(QString("Invalid JSON in config file: %1").arg(error.errorString()));
        return false;
    }
    
    QJsonObject root = doc.object();
    if (!root.contains("active_transmissions")) {
        emit showError("Config file missing 'active_transmissions' section");
        return false;
    }
    
    emit showSuccess("Config file validation passed");
    return true;
}

QStringList DbcParser::getConfigSummary(const QUrl &fileUrl) {
    QStringList summary;
    
    QString filePath = fileUrl.toLocalFile();
    if (!QFile::exists(filePath)) {
        summary << "Error: File does not exist";
        return summary;
    }
    
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        summary << "Error: Cannot open file";
        return summary;
    }
    
    QByteArray data = file.readAll();
    file.close();
    
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);
    
    if (error.error != QJsonParseError::NoError) {
        summary << QString("Error: Invalid JSON - %1").arg(error.errorString());
        return summary;
    }
    
    QJsonObject root = doc.object();
    summary << QString("Version: %1").arg(root["version"].toString());
    summary << QString("Created: %1").arg(root["created"].toString());
    
    QJsonArray transmissions = root["active_transmissions"].toArray();
    summary << QString("Total transmissions: %1").arg(transmissions.size());
    
    for (const QJsonValue &value : transmissions) {
        QJsonObject trans = value.toObject();
        QString messageName = trans["messageName"].toString();
        int rateMs = trans["rateMs"].toInt();
        QString status = trans["status"].toString();
        summary << QString("- %1: %2ms, %3").arg(messageName).arg(rateMs).arg(status);
    }
    
    return summary;
}

bool DbcParser::mergeActiveTransmissionsConfig(const QUrl &fileUrl, bool replaceExisting) {
    if (!validateConfigFile(fileUrl)) {
        return false;
    }
    
    QString filePath = fileUrl.toLocalFile();
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        emit showError("Cannot open config file for merging");
        return false;
    }
    
    QByteArray data = file.readAll();
    file.close();
    
    QJsonDocument doc = QJsonDocument::fromJson(data);
    QJsonObject root = doc.object();
    QJsonArray transmissions = root["active_transmissions"].toArray();
    
    int mergedCount = 0;
    int skippedCount = 0;
    
    for (const QJsonValue &value : transmissions) {
        QJsonObject transObj = value.toObject();
        ActiveTransmission trans;
        trans.messageName = transObj["messageName"].toString();
        trans.messageId = transObj["messageId"].toInt();
        trans.rateMs = transObj["rateMs"].toInt();
        trans.status = transObj["status"].toString();
        trans.isPaused = (trans.status == "Paused");
        
        // Check if transmission already exists
        bool exists = false;
        for (int i = 0; i < m_activeTransmissions.size(); ++i) {
            if (m_activeTransmissions[i].messageName == trans.messageName) {
                exists = true;
                if (replaceExisting) {
                    m_activeTransmissions[i] = trans;
                    mergedCount++;
                } else {
                    skippedCount++;
                }
                break;
            }
        }
        
        if (!exists) {
            m_activeTransmissions.append(trans);
            mergedCount++;
        }
    }
    
    emit activeTransmissionsChanged();
    emit showSuccess(QString("Merged %1 transmissions, skipped %2 existing").arg(mergedCount).arg(skippedCount));
    return true;
}

QString DbcParser::testConfigLoad() {
    QString result = "Testing config load:\n";
    
    QString configPath = QDir::currentPath() + "/simpbms_transmission_config.json";
    result += QString("Config path: %1\n").arg(configPath);
    
    if (QFile::exists(configPath)) {
        result += "File exists: YES\n";
        QUrl fileUrl = QUrl::fromLocalFile(configPath);
        result += QString("QUrl: %1\n").arg(fileUrl.toString());
        
        bool success = loadActiveTransmissionsConfig(fileUrl);
        result += QString("Load result: %1\n").arg(success ? "SUCCESS" : "FAILED");
        
        result += QString("Active transmissions count: %1\n").arg(m_activeTransmissions.size());
    } else {
        result += "File exists: NO\n";
    }
    
    return result;
}