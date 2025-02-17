#include "DbcParser.h"
#include <QFile>
#include <QTextStream>
#include <QDebug>
//check for errors before parsing.

DbcParser::DbcParser(QObject *parent) : QObject(parent) {}

void DbcParser::loadDbcFile(const QString &filePath) {
    parseDbcFile(filePath);
    emit messagesUpdated();
}

void DbcParser::parseDbcFile(const QString &filePath) {
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "Failed to open DBC file:" << filePath;
        return;
    }

    QTextStream in(&file);
    messages.clear();

    while (!in.atEnd()) {
        QString line = in.readLine();
        if (line.startsWith("BO_ ")) {
            QStringList parts = line.split(" ");
            if (parts.size() < 3) continue;
            int id = parts[1].toInt();
            QString name = parts[2];
            messages[name] = {id, name, {}};
        } else if (line.startsWith(" SG_ ")) {
            QStringList parts = line.split(" ");
            if (parts.size() < 6) continue;
            QString msgName = parts[1];
            QString sigName = parts[2];
            int startBit = parts[3].toInt();
            int length = parts[4].toInt();
            bool isLittleEndian = parts[5].contains("@");

            if (messages.find(msgName) != messages.end()) {
                messages[msgName].signalss.push_back({sigName, startBit, length, isLittleEndian});
            }
        }
    }

    file.close();
}

void DbcParser::selectMessage(const QString &messageName) {
    if (messages.find(messageName) != messages.end()) {
        selectedMessage = messageName;
        emit signalsUpdated();
    }
}

void DbcParser::setShowAllSignals(bool showAll) {
    showAllSignals = showAll;
    emit signalsUpdated();
}

void DbcParser::setEndian(const QString &endian) {
    littleEndian = (endian == "little");
    updateOutput();
}

void DbcParser::updateOutput() {
    if (selectedMessage.isEmpty() || messages.find(selectedMessage) == messages.end()) return;

    Message msg = messages[selectedMessage];
    QString output = QString::number(msg.id, 16).toUpper() + "#0000000000000000";
    emit outputUpdated(output);
}
