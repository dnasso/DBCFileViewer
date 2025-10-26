#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QQuickStyle>
#include <QWindow>
#include <QTimer>
#include "DBCClient/Qtclient.h"
#include "DbcParser.h"
#include <QDebug>
#include <QFile>
#include <QIcon>
#include <QTextStream>
#include <QDateTime>

// Import the Qt::StringLiterals namespace
using namespace Qt::StringLiterals;

namespace {
QString gLogPath;
bool gShuttingDown = false;

QString logLevelToString(QtMsgType type)
{
    switch (type) {
    case QtDebugMsg:
        return QStringLiteral("DEBUG");
    case QtInfoMsg:
        return QStringLiteral("INFO");
    case QtWarningMsg:
        return QStringLiteral("WARN");
    case QtCriticalMsg:
        return QStringLiteral("CRIT");
    case QtFatalMsg:
        return QStringLiteral("FATAL");
    }
    return QStringLiteral("LOG");
}

void appendLogLine(const QString &path, const QString &line)
{
    if (path.isEmpty()) {
        return;
    }
    QFile file(path);
    if (file.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        QTextStream stream(&file);
        stream << line << Qt::endl;
    }
}

void messageHandler(QtMsgType type, const QMessageLogContext &, const QString &msg)
{
    if (gLogPath.isEmpty() || gShuttingDown) {
        return;
    }
    const QString timestamp = QDateTime::currentDateTime().toString(Qt::ISODate);
    appendLogLine(gLogPath, QStringLiteral("%1 [%2] %3").arg(timestamp, logLevelToString(type), msg));
}
}

int main(int argc, char *argv[])
{
    // Set application metadata for proper window identification
    QGuiApplication::setApplicationName("DBC File Viewer");
    QGuiApplication::setOrganizationName("DBCFileViewer");
    QGuiApplication::setApplicationDisplayName("DBC File Viewer");

    QGuiApplication app(argc, argv);

    // Check for command-line arguments (file to open)
    QString fileToOpen;
    QStringList args = app.arguments();
    if (args.size() > 1) {
        // Skip the first argument (program name) and look for a .dbc file
        for (int i = 1; i < args.size(); ++i) {
            if (args[i].endsWith(".dbc", Qt::CaseInsensitive)) {
                fileToOpen = args[i];
                qDebug() << "File to open from command line:" << fileToOpen;
                break;
            }
        }
    }

    // Set window icon (must be set before any windows are created)
    const auto iconPathIco = QStringLiteral(":/deploy-assets/dbctrain.ico");
    const auto iconPathPng = QStringLiteral(":/deploy-assets/dbctrain.png");

    const QString logPath = QCoreApplication::applicationDirPath() + "/icon_debug.log";
    gLogPath = logPath;
    qInstallMessageHandler(messageHandler);

    appendLogLine(logPath, QStringLiteral("iconPathIco exists=%1, iconPathPng exists=%2")
                              .arg(QFile::exists(iconPathIco))
                              .arg(QFile::exists(iconPathPng)));

    if (!QFile::exists(iconPathIco) || !QFile::exists(iconPathPng)) {
        qWarning() << "Icon resource missing" << iconPathIco << QFile::exists(iconPathIco)
                   << iconPathPng << QFile::exists(iconPathPng);
    }

    QIcon icon;
    icon.addFile(iconPathIco);
    icon.addFile(iconPathPng);
    if (!icon.isNull()) {
        app.setWindowIcon(icon);
    } else {
        qWarning() << "Failed to load window icon from resources";
    }

    registerTcpClientBackend();

    // Set the Material style
    QQuickStyle::setStyle("Material");

    // Create the DBC parser
    DbcParser dbcParser;

    QQmlApplicationEngine engine;

    // Make the parser available to QML
    engine.rootContext()->setContextProperty("dbcParser", &dbcParser);

    // Use the previously working URL path
    const QUrl url(u"qrc:/qt/qml/DBC_Parser/Main.qml"_s);

    QObject::connect(&engine, &QQmlApplicationEngine::warnings,
                     [&logPath](const QList<QQmlError> &warnings) {
        for (const auto &warning : warnings) {
            appendLogLine(logPath, QStringLiteral("QML warning: %1").arg(warning.toString()));
        }
    });

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url, icon, logPath](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);

        if (auto window = qobject_cast<QWindow *>(obj)) {
            QFile logFile(logPath);
            if (logFile.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
                QTextStream logStream(&logFile);
                logStream << "Setting icon on window, icon.isNull=" << icon.isNull() << Qt::endl;
                logFile.close();
            } else {
                appendLogLine(logPath + ".error",
                             QStringLiteral("Failed to append icon log in handler: %1").arg(logFile.errorString()));
            }
            window->setIcon(icon);
        }
    }, Qt::QueuedConnection);
    
    // Connect aboutToQuit signal for proper cleanup
    QObject::connect(&app, &QGuiApplication::aboutToQuit, [&dbcParser]() {
        qDebug() << "Application about to quit - performing cleanup...";
        dbcParser.disconnectFromServer();
        qInstallMessageHandler(nullptr);
        gShuttingDown = true;
        qDebug() << "Cleanup completed";
    });

    engine.load(url);

    if (engine.rootObjects().isEmpty()) {
        appendLogLine(logPath, QStringLiteral("No root objects after engine.load"));
    } else {
        if (auto window = qobject_cast<QWindow *>(engine.rootObjects().first())) {
            appendLogLine(logPath, QStringLiteral("Post-load icon applied, icon.isNull=%1").arg(icon.isNull()));
            window->setIcon(icon);
        } else {
            appendLogLine(logPath, QStringLiteral("First root object is not a QWindow (%1)").arg(engine.rootObjects().first()->metaObject()->className()));
        }
    }

    // If a file was specified on the command line, load it after the UI is initialized
    if (!fileToOpen.isEmpty()) {
        QTimer::singleShot(500, [&dbcParser, fileToOpen]() {
            QUrl fileUrl = QUrl::fromLocalFile(fileToOpen);
            qDebug() << "Loading file from command line:" << fileUrl;
            dbcParser.loadDbcFile(fileUrl);
        });
    }

    return app.exec();
}
