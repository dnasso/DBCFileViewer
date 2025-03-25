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