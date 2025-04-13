#include "DbcParser.h"
#include <QFile>
#include <QTextStream>
#include <QRegularExpression>
#include <QFileInfo>
#include <QDebug>
#include <sstream>
#include <iostream>
#include <iomanip>
#include <bitset>
#include <cmath>

DbcParser::DbcParser(QObject *parent)
    : QObject(parent), selectedMessageIndex(-1), showAllSignals(false), currentEndian("little")
{
    // Initialize with some default values
    m_generatedCanFrame = "";
}

bool DbcParser::loadDbcFile(const QUrl &fileUrl)
{
    QString filePath = fileUrl.toLocalFile();
    if (filePath.isEmpty()) {
        qWarning() << "Empty file path";
        return false;
    }

    QFileInfo fileInfo(filePath);
    if (!fileInfo.exists()) {
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
    
    // For each signal, pack its value into the frame
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
    
    // For each signal, pack its value into the frame
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

