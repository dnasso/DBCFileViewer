#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include "DBCClient/Qtclient.h"
#include "DbcParser.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    registerTcpClientBackend();

    // Set the Material style
    QQuickStyle::setStyle("Material");

    // Create the DBC parser
    DbcParser dbcParser;

    QQmlApplicationEngine engine;

    // Make the parser available to QML
    engine.rootContext()->setContextProperty("dbcParser", &dbcParser);

    // Use Qt6.2 compatible URL path
    const QUrl url(QStringLiteral("qrc:/qt/qml/DBC_Parser/Main.qml"));

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);
    
    // Connect aboutToQuit signal for proper cleanup
    QObject::connect(&app, &QGuiApplication::aboutToQuit, [&dbcParser]() {
        qDebug() << "Application about to quit - performing cleanup...";
        dbcParser.disconnectFromServer();
        qDebug() << "Cleanup completed";
    });

    engine.load(url);

    return app.exec();
}
